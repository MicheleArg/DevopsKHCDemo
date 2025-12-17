#!/bin/bash


checkAction() {
    if [ $actionType == 'validate' ]; then
        validateDeploy
    elif [ $actionType == 'deploy' ]; then
        deploy
    else
        echo "No action available"
    fi
}

deploy(){
    echo "Starting Deploy"
    echo "Env target: $envTarget"
    echo "Source branch: $sourceBranch"
    echo "Test to run: $testToRun"

    #scarico tutti i branch dal remoto
    alignBranches

    #controllo i branch
    checkBranch $sourceBranch

    getLastTag

    getCommitsFromTag

    getDiffFiles

    createDiffPackage

    createReleasePackage

    deploySFDC

    createTag
}

createTag(){
    local config_file="DevOpsConfig/config.json"
    
    echo "🏷️  Creazione tag post-deployment..."
    
    # Estrai solo il tagName dal config
    local tag_prefix
    if command -v jq >/dev/null 2>&1; then
        tag_prefix=$(jq -r '.tagName // empty' "$config_file")
    else
        tag_prefix=$(grep -oP '"tagName"\s*:\s*"\K[^"]+' "$config_file")
    fi
    
    [ -z "$tag_prefix" ] && echo "❌ tagName non trovato" && return 1
    
    # Ottieni il branch corrente (quello su cui è stato fatto il merge)
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo "📍 Branch corrente: $current_branch"
    
    # Genera tag: {tagName}{AAAAMMGGHHMMSS}_Salesforce
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local tag_name="${tag_prefix}${timestamp}_Salesforce"
    
    echo "📝 Tag: $tag_name"
    
    # Crea e pusha il tag
    git tag -a "$tag_name" -m "Deploy su $envTarget dal branch $current_branch - $(date '+%Y-%m-%d %H:%M:%S')" && \
    git push origin "$tag_name" && \
    echo "✅ Tag $tag_name creato su $current_branch" || \
    (echo "❌ Errore creazione tag" && return 1)
}

deploySFDC(){
    local config_file="DevOpsConfig/config.json"
    
    echo "🔐 Caricamento configurazioni..."
    
    # Verifica esistenza file config
    if [ ! -f "$config_file" ]; then
        echo "❌ File di configurazione non trovato: $config_file"
        return 1
    fi
    
    # Estrai configurazioni dal JSON
    local client_id username server_key instance_url
    
    if command -v jq >/dev/null 2>&1; then
        client_id=$(jq -r --arg env "$envTarget" '.[$env].clientId // empty' "$config_file")
        username=$(jq -r --arg env "$envTarget" '.[$env].username // empty' "$config_file")
        server_key=$(jq -r --arg env "$envTarget" '.[$env].serverKey // empty' "$config_file")
        instance_url=$(jq -r --arg env "$envTarget" '.[$env].instanceUrl // empty' "$config_file")
    else
        client_id=$(grep -oP '"(clientId|client_id)"\s*:\s*"\K[^"]+' "$config_file" | head -1)
        username=$(grep -oP '"username"\s*:\s*"\K[^"]+' "$config_file")
        server_key=$(grep -oP '"(serverKey|server_key)"\s*:\s*"\K[^"]+' "$config_file" | head -1)
        instance_url=$(grep -oP '"(instanceUrl|instance_url)"\s*:\s*"\K[^"]+' "$config_file" | head -1)
        instance_url=${instance_url:-"https://login.salesforce.com"}
    fi
    
    # Validazione parametri
    if [ -z "$client_id" ] || [ -z "$username" ] || [ -z "$server_key" ]; then
        echo "❌ Parametri mancanti nel file di configurazione"
        echo "   - clientId: ${client_id:-(mancante)}"
        echo "   - username: ${username:-(mancante)}"
        echo "   - serverKey: ${server_key:-(mancante)}"
        return 1
    fi
    
    # Verifica esistenza server.key
    if [ ! -f "$server_key" ]; then
        echo "❌ File server key non trovato: $server_key"
        return 1
    fi
    
    echo "✅ Configurazioni caricate"
    echo "   - Target Org: $envTarget"
    echo "   - Username: $username"
    echo "   - Instance: $instance_url"
    
    # Login a Salesforce
    echo ""
    echo "🔑 Autenticazione Salesforce..."
    if ! sf org login jwt \
        --client-id "$client_id" \
        --jwt-key-file "$server_key" \
        --username "$username" \
        --alias "$envTarget" \
        --instance-url "$instance_url"; then
        echo "❌ Errore durante l'autenticazione"
        return 1
    fi
    
    echo "✅ Autenticazione completata"
    
    # Deployment
    local package_xml="./Release/codepkg/package.xml"
    
    if [ ! -f "$package_xml" ]; then
        echo "❌ Package.xml non trovato: $package_xml"
        return 1
    fi
    
    echo ""
    echo "📦 Avvio validazione package..."
    
    if [ "$testToRun" == 'true' ]; then
        # Con test specificati
        test_list=""
        createTestList
        
        if [ -z "$test_list" ]; then
            echo "⚠️  Nessun test trovato, eseguo senza test"
            testToRun='false'
        else
            echo "🧪 Test da eseguire: $test_list"
            
            if sf project deploy start \
                --source-dir "./Release/force-app/main/default" \
                --test-level RunSpecifiedTests \
                --tests "$test_list" \
                --target-org "$envTarget"; then
                echo "✅ Deployment completato con successo"
                return 0
            else
                echo "❌ Deployment fallito"
                return 1
            fi
        fi
    fi
    
    # Senza test
    if [ "$testToRun" != 'true' ]; then
        echo "⚠️  Deployment senza esecuzione test"
        
        if sf project deploy start \
            --source-dir "./Release/force-app/main/default" \
            --test-level NoTestRun \
            --target-org "$envTarget"; then
            echo "✅ Deployment completato con successo"
            return 0
        else
            echo "❌ Deployment fallito"
            return 1
        fi
    fi
    
}

validateDeploy(){
    echo "Starting Validate"
    echo "Env target: $envTarget"
    echo "Source branch: $sourceBranch"
    echo "Test to run: $testToRun"

    #scarico tutti i branch dal remoto
    alignBranches

    #controllo i branch
    checkBranch $sourceBranch

    getLastTag

    getCommitsFromTag

    getDiffFiles

    createDiffPackage

    createReleasePackage

    validate
}

pullRequestCreation(){
    echo "Starting Pull Request Creation"
    echo "Env target: $envTarget"
    echo "Source branch: $sourceBranch"
    echo "Destination branch: $destBranch"
    echo "Test to run: $testToRun"

    #scarico tutti i branch dal remoto
    alignBranches

    #controllo i branch
    checkBranch $sourceBranch
    checkBranch $destBranch

    #prendo l'ultimo tag
    getLastTag

    getCommitsFromTag

    getDiffFiles

    createDiffPackage

    createReleasePackage

    validate

    createPR
}


cretaDeployScript(){
    echo '' > deploy.xml
    test_list=$1
    env=$2
    testLevel=$3
    checkOnly=$4
    echo '<project name="Sample usage of Salesforce Ant tasks" default="test" basedir="." xmlns:sf="antlib:com.salesforce">
              <property file="build.properties"/>
              <property environment="env"/>
              <property name="ant.build.javac.source" value="1.8"/>
              <property name="ant.build.javac.target" value="1.8"/>
              <property name="test.list" value=""/>

              <taskdef resource="com/salesforce/antlib.xml" uri="antlib:com.salesforce">
                <classpath>
                    <pathelement location="./ant-salesforce.jar" />        	
                </classpath>
              </taskdef>
          
              <property file="build.properties"/>
              <target name="test">
              <sf:deploy username="${sf.username'$env'}" password="${sf.password'$env'}" serverurl="${sf.serverurl'$env'}" deployRoot="./Release/codepkg" testLevel="'$testLevel'" checkOnly="'$checkOnly'">' >> deploy.xml

    IFS=',' read -r -a array <<< "$test_list"
    unique_array=$(echo "$array" | tr ' ' '\n' | sort | uniq | tr '\n' ' ')
    echo $unique_array
    for value in "${unique_array[@]}"
    do
        if [ $value != '' ]; then : 
            echo "<runTest>"$value"</runTest>"
            trimmed_string=$(echo "<runTest>"$value"</runTest>" | tr -d ' ')
            echo $trimmed_string >> deploy.xml
        fi
    done

    echo "</sf:deploy></target></project>" >> deploy.xml
    
}

validate(){
    local config_file="DevOpsConfig/config.json"
    
    echo "🔐 Caricamento configurazioni..."
    
    # Verifica esistenza file config
    if [ ! -f "$config_file" ]; then
        echo "❌ File di configurazione non trovato: $config_file"
        return 1
    fi
    
    # Estrai configurazioni dal JSON
    local client_id username server_key instance_url
    
    if command -v jq >/dev/null 2>&1; then
        client_id=$(jq -r --arg env "$envTarget" '.[$env].clientId // empty' "$config_file")
        username=$(jq -r --arg env "$envTarget" '.[$env].username // empty' "$config_file")
        server_key=$(jq -r --arg env "$envTarget" '.[$env].serverKey // empty' "$config_file")
        instance_url=$(jq -r --arg env "$envTarget" '.[$env].instanceUrl // empty' "$config_file")
    else
        client_id=$(grep -oP '"(clientId|client_id)"\s*:\s*"\K[^"]+' "$config_file" | head -1)
        username=$(grep -oP '"username"\s*:\s*"\K[^"]+' "$config_file")
        server_key=$(grep -oP '"(serverKey|server_key)"\s*:\s*"\K[^"]+' "$config_file" | head -1)
        instance_url=$(grep -oP '"(instanceUrl|instance_url)"\s*:\s*"\K[^"]+' "$config_file" | head -1)
        instance_url=${instance_url:-"https://login.salesforce.com"}
    fi
    
    # Validazione parametri
    if [ -z "$client_id" ] || [ -z "$username" ] || [ -z "$server_key" ]; then
        echo "❌ Parametri mancanti nel file di configurazione"
        echo "   - clientId: ${client_id:-(mancante)}"
        echo "   - username: ${username:-(mancante)}"
        echo "   - serverKey: ${server_key:-(mancante)}"
        return 1
    fi
    
    # Verifica esistenza server.key
    if [ ! -f "$server_key" ]; then
        echo "❌ File server key non trovato: $server_key"
        return 1
    fi
    
    echo "✅ Configurazioni caricate"
    echo "   - Target Org: $envTarget"
    echo "   - Username: $username"
    echo "   - Instance: $instance_url"
    
    # Login a Salesforce
    echo ""
    echo "🔑 Autenticazione Salesforce..."
    if ! sf org login jwt \
        --client-id "$client_id" \
        --jwt-key-file "$server_key" \
        --username "$username" \
        --alias "$envTarget" \
        --instance-url "$instance_url"; then
        echo "❌ Errore durante l'autenticazione"
        return 1
    fi
    
    echo "✅ Autenticazione completata"
    
    # Deployment/Validation
    local package_xml="./Release/codepkg/package.xml"
    
    if [ ! -f "$package_xml" ]; then
        echo "❌ Package.xml non trovato: $package_xml"
        return 1
    fi
    
    echo ""
    echo "📦 Avvio validazione package..."
    
    if [ "$testToRun" == 'true' ]; then
        # Con test specificati
        test_list=""
        createTestList
        
        if [ -z "$test_list" ]; then
            echo "⚠️  Nessun test trovato, eseguo senza test"
            testToRun='false'
        else
            echo "🧪 Test da eseguire: $test_list"
            
            if sf project deploy validate \
                --source-dir "./Release/force-app/main/default" \
                --test-level RunSpecifiedTests \
                --tests "$test_list" \
                --target-org "$envTarget"; then
                echo "✅ Validazione completata con successo"
                return 0
            else
                echo "❌ Validazione fallita"
                return 1
            fi
        fi
    fi
    
    # Senza test
    if [ "$testToRun" != 'true' ]; then
        echo "⚠️  Validazione senza esecuzione test"
        
        if sf project deploy validate \
            --source-dir "./Release/force-app/main/default" \
            --test-level NoTestRun \
            --target-org "$envTarget"; then
            echo "✅ Validazione completata con successo"
            return 0
        else
            echo "❌ Validazione fallita"
            return 1
        fi
    fi
}

createTestList(){
    local package_path="./Release/force-app/main/default/classes"
    local json_file="test-catalog.json"
    local default_test=$(jq -r '.default // empty' "$json_file")
    echo "📋 Test di default: ${default_test:-"nessuno"}"
    
    echo "🧪 Creazione lista test da eseguire..."
    
    # Verifica esistenza file JSON
    if [ ! -f "$json_file" ]; then
        echo "❌ File $json_file non trovato"
        return 1
    fi
    
    declare -A test_set

    # Verifica esistenza cartella classes
    if [ ! -d "$package_path" ]; then
        echo "⚠️  Nessuna cartella classes trovata in $package_path"

        if [ -n "$default_test" ]; then
            echo "⚙️  Uso test di default dal catalogo: $default_test"
            echo "$default_test"
            test_set["$default_test"]=1
        else
            echo "⚠️  Nessun test di default configurato"
        fi

        return 0
    fi
    
    # Array per evitare duplicati
    local class_count=0
    local test_count=0
    
    echo ""
    echo "📦 Scansione classi nel package..."
    
    # Trova tutti i file .cls nel package
    while IFS= read -r class_file; do
        # Estrae il nome della classe (senza percorso e senza estensione)
        local class_name=$(basename "$class_file" .cls)
        
        # Salta i file -meta.xml
        [[ "$class_name" == *"-meta" ]] && continue
        
        ((class_count++))
        echo "  📄 Classe trovata: $class_name"
        
        # Cerca il test corrispondente nel JSON
        local test_class=$(jq -r --arg class "$class_name" '.[$class] // empty' "$json_file")
        
        if [ -n "$test_class" ]; then
            # Test specifico trovato
            echo "     ✓ Test specifico: $test_class"
            test_set["$test_class"]=1
        else
            echo "     ⚠️  Nessun test configurato"
        fi
        
    done < <(find "$package_path" -name "*.cls" -type f)
    
    # Costruisce la lista dei test (senza duplicati)
    for test in "${!test_set[@]}"; do
        if [[ -z "$test_list" ]]; then
            test_list="$test"
        else
            test_list="$test_list $test"
        fi
        ((test_count++))
    done
    
    echo ""
    echo "📊 Riepilogo:"
    echo "   Classi trovate: $class_count"
    echo "   Test da eseguire: $test_count"
    echo ""
    
    if [ -n "$test_list" ]; then
        echo "✅ Lista test generata:"
        echo "   $test_list"
        echo ""
        echo "🚀 Comando per eseguire i test:"
        echo "   sf apex run test --tests $test_list --result-format human --code-coverage --wait 10"
    else
        echo "⚠️  Nessun test da eseguire"
    fi
    
    # Esporta la variabile per usarla fuori dalla funzione
    echo "$test_list"
}

createReleasePackage(){
    basePath="Release/"
    if [ -d "$basePath""codepkg" ]; then rm -Rf "$basePath""codepkg"; fi

    if sf project convert source -r "$basePath""force-app/main/default"  -d "$basePath""codepkg"; then 
        echo "✅ Conversione completata"
    
        # Se esiste la cartella profiles in default, sostituiscila in codepkg
        if [ -d "$basePath""force-app/main/default/profiles" ]; then
            echo "📁 Trovata cartella profiles in default"
            
            # Rimuovi la cartella profiles generata in codepkg
            rm -rf "$basePath""codepkg/profiles"
            
            # Copia la cartella profiles da default a codepkg
            cp -r "$basePath""force-app/main/default/profiles" "$basePath""codepkg/"
            
            echo "✅ Cartella profiles sostituita in codepkg"
        else
            echo "⚠️  Nessuna cartella profiles trovata in default"
        fi
    else 
        echo "[Error] Error converting to mdapi..."
        echo "[Error] Source path: ""$basePath""force-app/main/default"
        echo "[Error] Destination path: ""$basePath""codepkg"
    fi
}

createDiffPackage(){
    local base_path="./Release/"
    local error_file="${base_path}error.txt"
    local diff_file="diff.txt"
    local config_file="DevOpsConfig/config.json"
    local rer=$(jq -r '.["Release"] // empty' "$config_file")

    local profiles_source="./profilesDevOps/"$rel"/"
    
    echo "📦 Creazione package Salesforce..."
    
    # Crea cartella Release e pulisce error.txt
    mkdir -p "$base_path"
    > "$error_file"
    
    # Verifica esistenza diff.txt
    if [ ! -f "$diff_file" ]; then
        echo "❌ File $diff_file non trovato"
        return 1
    fi
    
    local success_count=0
    local error_count=0
    local processed_dirs=()
    
    while IFS= read -r line; do
        # Salta righe vuote, con virgolette o non force-app
        [ -z "$line" ] && continue
        [[ "$line" == *"\""* ]] && echo "$line" >> "$error_file" && continue
        # Se NON contiene "force-app" MA contiene "profilesDevOps", deve essere considerato profilo
        if [[ "$line" != *"force-app"* ]] && [[ "$line" != *"profilesDevOps"* ]]; then
            echo "$line" >> "$error_file"
            continue
        fi        
        # Determina il tipo di componente e gestiscilo
        if [[ "$line" == *"profilesDevOps/"* ]]; then
            # PROFILES: leggi da profilesDevOps/
            if handleProfileFromExternal "$line" "$base_path" "$profiles_source" "$error_file"; then
                ((success_count++))
            else
                ((error_count++))
            fi
            
        elif [[ "$line" == *"/aura/"* ]]; then
            # AURA: copia intera cartella componente
            local component_dir=$(getComponentDir "$line" "/aura/")
            if ! isProcessed "$component_dir" "${processed_dirs[@]}"; then
                if handleBundleComponent "$line" "$base_path" "$error_file" "/aura/"; then
                    processed_dirs+=("$component_dir")
                    ((success_count++))
                else
                    ((error_count++))
                fi
            fi
            
        elif [[ "$line" == *"/lwc/"* ]]; then
            # LWC: copia intera cartella componente
            local component_dir=$(getComponentDir "$line" "/lwc/")
            if ! isProcessed "$component_dir" "${processed_dirs[@]}"; then
                if handleBundleComponent "$line" "$base_path" "$error_file" "/lwc/"; then
                    processed_dirs+=("$component_dir")
                    ((success_count++))
                else
                    ((error_count++))
                fi
            fi
            
        elif [[ "$line" == *"/experiences/"* ]] || [[ "$line" == *"/experienceBundles/"* ]]; then
            # EXPERIENCE BUNDLE: copia intera cartella
            local bundle_dir=$(getComponentDir "$line" "/experiences/")
            [ -z "$bundle_dir" ] && bundle_dir=$(getComponentDir "$line" "/experienceBundles/")
            
            if ! isProcessed "$bundle_dir" "${processed_dirs[@]}"; then
                if handleBundleComponent "$line" "$base_path" "$error_file" "/experiences/|/experienceBundles/"; then
                    processed_dirs+=("$bundle_dir")
                    ((success_count++))
                else
                    ((error_count++))
                fi
            fi
            
        else
            # FILE STANDARD: copia file + meta.xml
            if handleStandardFile "$line" "$base_path" "$error_file"; then
                ((success_count++))
            else
                ((error_count++))
            fi
        fi
        
    done < "$diff_file"
    
    echo ""
    echo "✅ Completato: $success_count file/componenti copiati"
    [ $error_count -gt 0 ] && echo "⚠️  Errori: $error_count (vedi $error_file)"
    
    # Mostra struttura creata
    echo ""
    echo "📁 Struttura package creata:"
    tree -L 4 "$base_path" 2>/dev/null || find "$base_path" -type d | head -20
    
    return 0
}

# Estrae la directory del componente bundle (aura/lwc/experiences)
getComponentDir(){
    local file_path="$1"
    local bundle_type="$2"
    
    # Estrae il percorso fino alla cartella del componente
    echo "$file_path" | grep -oP ".*${bundle_type}[^/]+" || echo ""
}

# Verifica se una directory è già stata processata
isProcessed(){
    local dir="$1"
    shift
    local processed=("$@")
    
    for proc_dir in "${processed[@]}"; do
        [ "$dir" = "$proc_dir" ] && return 0
    done
    return 1
}

# Gestisce componenti bundle (Aura, LWC, Experience)
handleBundleComponent(){
    local file_path="$1"
    local base_path="$2"
    local error_file="$3"
    local bundle_pattern="$4"
    
    # Trova la directory del componente
    local component_dir=""
    if [[ "$bundle_pattern" == *"|"* ]]; then
        # Multipli pattern (es: experiences o experienceBundles)
        for pattern in $(echo "$bundle_pattern" | tr '|' ' '); do
            component_dir=$(echo "$file_path" | grep -oP ".*${pattern}[^/]+")
            [ -n "$component_dir" ] && break
        done
    else
        component_dir=$(echo "$file_path" | grep -oP ".*${bundle_pattern}[^/]+")
    fi
    
    if [ -z "$component_dir" ] || [ ! -d "$component_dir" ]; then
        echo "⚠️  Cartella componente non trovata: $file_path" >> "$error_file"
        return 1
    fi
    
    local parent_dir=$(dirname "$component_dir")
    local component_name=$(basename "$component_dir")
    
    # Crea directory padre e copia intera cartella componente
    if mkdir -p "$base_path$parent_dir" && cp -r "$component_dir" "$base_path$parent_dir/"; then
        echo "📦 Bundle: $component_name"
        return 0
    else
        echo "❌ Errore copia bundle: $component_dir"
        echo "$file_path" >> "$error_file"
        return 1
    fi
}

# Gestisce file standard con eventuale -meta.xml
handleStandardFile(){
    local file_path="$1"
    local base_path="$2"
    local error_file="$3"
    
    # Verifica che il file esista
    if [ ! -f "$file_path" ]; then
        echo "⚠️  File non trovato: $file_path" >> "$error_file"
        return 1
    fi
    
    local dir_path=$(dirname "$file_path")
    local file_name=$(basename "$file_path")
    
    # Crea directory di destinazione
    if ! mkdir -p "$base_path$dir_path"; then
        echo "$file_path" >> "$error_file"
        return 1
    fi
    
    # Copia file principale
    if ! cp "$file_path" "$base_path$dir_path/"; then
        echo "❌ Errore copia: $file_path"
        echo "$file_path" >> "$error_file"
        return 1
    fi
    
    # Se non è già un -meta.xml, cerca e copia il suo meta.xml
    if [[ "$file_path" != *"-meta.xml" ]]; then
        local meta_file="${file_path}-meta.xml"
        if [ -f "$meta_file" ]; then
            if ! cp "$meta_file" "$base_path$dir_path/"; then
                echo "⚠️  Errore copia meta.xml: $meta_file" >> "$error_file"
            fi
        fi
    fi
    
    echo "📄 File: $file_name"
    return 0
}

# Gestisce profiles dalla cartella esterna profilesDevOps/
handleProfileFromExternal(){
    local file_path="$1"
    local base_path="$2"
    local profiles_source="$3"
    local error_file="$4"
    
    echo "🔍 DEBUG Profile - file_path ricevuto: '$file_path'"
    
    # Pulisci eventuali spazi o caratteri speciali
    file_path=$(echo "$file_path" | xargs)
    
    # Estrae il percorso relativo dopo profilesDevOps/
    # Es: "profilesDevOps/R2/Admin.profile-meta.xml" -> "R2/Admin.profile-meta.xml"
    local relative_path="${file_path#profilesDevOps/}"
    local profile_name=$(basename "$file_path")
    echo "🔍 DEBUG Profile - relative_path: '$relative_path'"
    echo "🔍 DEBUG Profile - profile_name: '$profile_name'"
    
    # Verifica esistenza cartella profilesDevOps
    if [ ! -d "$profiles_source" ]; then
        echo "❌ Cartella $profiles_source non trovata!"
        echo "   Path completo testato: $(pwd)/$profiles_source"
        echo "$file_path" >> "$error_file"
        return 1
    fi
    
    echo "✓ Cartella profilesDevOps trovata"
    
    # Usa il percorso relativo completo (include sottocartelle)
    local source_profile="${profiles_source}${relative_path}"
    echo "🔍 DEBUG Profile - source_profile: '$source_profile'"
    
    if [ ! -f "$source_profile" ]; then
        echo "❌ Profile non trovato: $source_profile"
        echo "   File cercati in $profiles_source:"
        ls -la "$profiles_source" 2>/dev/null | head -5
        echo "$file_path" >> "$error_file"
        return 1
    fi
    
    echo "✓ File sorgente trovato: $source_profile"
    
    # Crea struttura force-app/main/default/profiles/ nel package
    local profile_dest_dir="${base_path}force-app/main/default/profiles"
    mkdir -p "$profile_dest_dir"
    echo "✓ Directory destinazione creata: $profile_dest_dir"
    
    # Copia profile da profilesDevOps/ a Release/force-app/main/default/profiles/
    if cp -v "$source_profile" "$profile_dest_dir/"; then
        echo "✅ Profile copiato: $profile_name → $profile_dest_dir/"
        
        # Copia anche il meta.xml se esiste
        local meta_file="${source_profile}-meta.xml"
        if [ -f "$meta_file" ]; then
            cp -v "$meta_file" "$profile_dest_dir/"
            echo "   + meta.xml copiato"
        fi
        
        return 0
    else
        echo "❌ Errore copia profile: $source_profile"
        echo "$file_path" >> "$error_file"
        return 1
    fi
}

getDiffFiles(){
    local commits_file="commits.txt"
    local output_file="diff.txt"
    
    # Verifica esistenza file commits
    if [ ! -f "$commits_file" ]; then
        echo "❌ File $commits_file non trovato"
        return 1
    fi
    
    echo "🔍 Analisi file modificati..."
    
    # Pulisce file di output se esiste
    > "$output_file"
    
    local commit_count=0
    
    # Legge solo il primo campo (hash) da ogni riga
    while IFS= read -r line; do
        # Estrae solo l'hash (prima parte prima di spazi, pipe, trattini)
        local commit_hash=$(echo "$line" | awk '{print $1}')
        
        # Salta righe vuote o header
        [ -z "$commit_hash" ] && continue
        [[ "$commit_hash" == "==="* ]] && continue
        
        # Verifica che sia un hash valido
        if git cat-file -e "$commit_hash" 2>/dev/null; then
            git diff-tree -r --no-commit-id --name-only --diff-filter=ACMRT "$commit_hash" 2>/dev/null
            ((commit_count++))
        fi
    done < "$commits_file" | sort -u > "$output_file"
    
    local file_count=$(wc -l < "$output_file")
    
    echo "✅ $file_count file unici modificati in $commit_count commit"
    echo ""
    echo "📄 File modificati:"
    cat "$output_file"
}

alignBranches(){
    echo "🔄 Sincronizzazione branch..."
    
    # Fetch tutti i branch remoti
    git fetch --all --prune
    
    # Per ogni branch remoto, crea il corrispondente branch locale se non esiste
    git branch -r | grep -v '\->' | grep -v 'HEAD' | sed 's/origin\///' | while read branch; do
        # Verifica se il branch locale esiste già
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            echo "✓ Branch '$branch' già esistente"
        else
            echo "➕ Creazione tracking branch '$branch'"
            git branch --track "$branch" "origin/$branch"
        fi
    done
    
    echo "✅ Sincronizzazione completata"
}

checkBranch(){
    # Verifica argomento
    if [ -z "$1" ]; then
        echo "❌ Errore: specificare il nome del branch"
        echo "Uso: checkBranch <nome-branch>"
        return 1
    fi

    local branch_name=$1
    
    # Controlla branch locale
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo "✅ Branch locale '$branch_name' esiste"
        return 0
    # Controlla branch remoto
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
        echo "📡 Branch remoto 'origin/$branch_name' esiste"
        return 0
    else
        echo "❌ Branch '$branch_name' non trovato"
        return 1
    fi
}

getLastTag(){
    local config_file="DevOpsConfig/config.json"
    
    # Verifica esistenza file config
    if [ ! -f "$config_file" ]; then
        echo "❌ Errore: file $config_file non trovato"
        return 1
    fi
    
    # Estrai tagName dal JSON (usando jq se disponibile, altrimenti grep/sed)
    local tag_prefix
    if command -v jq >/dev/null 2>&1; then
        tag_prefix=$(jq -r --arg env "$envTarget" '.[$env].tagName // empty' "$config_file")
    else
        # Fallback senza jq - cerca dentro l'ambiente specifico
        tag_prefix=$(grep -A 10 "\"$envTarget\"" "$config_file" | grep -o '"tagName"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"tagName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
    fi
    
    # Verifica che tagName sia stato trovato
    if [ -z "$tag_prefix" ] || [ "$tag_prefix" = "null" ]; then
        echo "❌ Errore: tagName non trovato in $config_file"
        return 1
    fi
    
    echo "🔍 Cerco tag con prefisso: $tag_prefix"
    
    # Fetch tags
    git fetch --tags --quiet
    
    # Trova l'ultimo tag con il prefisso specificato
    ultimo_tag=$(git tag -l "${tag_prefix}*" --sort=-version:refname | head -n 1)
    
    if [ -z "$ultimo_tag" ]; then
        echo "⚠️  Nessun tag trovato con prefisso '$tag_prefix'"
        return 1
    fi
    
    echo "✅ Ultimo tag: $ultimo_tag"
    echo "$ultimo_tag"  # Return del valore per usarlo in altre funzioni
}

getCommitsFromTag(){
    echo "🔍 Recupero ultimo tag..."
    
    # Ottiene l'ultimo tag dalla funzione precedente
    
    if [ -z "$ultimo_tag" ]; then
        echo "⚠️  Nessun tag trovato - recupero tutte le commit"
        
        # Ottiene tutte le commit del branch corrente
        local commits=$(git log --no-merges --pretty=format:"%h - %s")
        
        if [ -z "$commits" ]; then
            echo "❌ Nessuna commit trovata nel repository"
            return 1
        fi
        
        # Salva tutte le commit
        echo "$commits" > commits.txt
        
        local commit_count=$(echo "$commits" | wc -l)
        echo "✅ $commit_count commit totali salvate in commits.txt"
        
    else
        echo "📋 Cerco commit dopo il tag: $ultimo_tag"
        
        # Ottiene commit escludendo i merge
        local commits=$(git log "$ultimo_tag..HEAD" --no-merges --pretty=format:"%h - %s")
        
        if [ -z "$commits" ]; then
            echo "⚠️  Nessun commit trovato dopo il tag '$ultimo_tag'"
            echo "Nessun commit dopo $ultimo_tag" > commits.txt
            return 0
        fi
        
        # Salva in commits.txt
        echo "$commits" > commits.txt
        
        local commit_count=$(echo "$commits" | wc -l)
        echo "✅ $commit_count commit salvati in commits.txt (da $ultimo_tag)"
    fi
    
    # Mostra preview
    echo ""
    echo "Preview primi 5 commit:"
    head -5 commits.txt
}

export LANG=en_us_8859_1

actionType=$1
envTarget=$2
sourceBranch=$3
destBranch=$4
testToRun=$5

checkAction




