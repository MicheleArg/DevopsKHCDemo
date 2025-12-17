/**
 * @description       : 
 * @author            : michele11.argentino@nttdata.com
 * @group             : 
 * @last modified on  : 12-17-2025
 * @last modified by  : michele11.argentino@nttdata.com
**/

/**
 * Classe di esempio con INTENZIONALI violazioni PMD per testare il report
 * NON USARE IN PRODUZIONE!
 */
public class KHC_CaseClass {
    
    // VIOLAZIONE: Variabile non utilizzata
    private String unusedVariable = 'never used';
    
    // VIOLAZIONE: Nome variabile non segue convenzioni (dovrebbe essere CONSTANT_NAME)
    private static final String badConstantName = 'value';
    
    // VIOLAZIONE: Troppi parametri (>4)
    public void methodWithTooManyParameters(
        String param1, 
        String param2, 
        String param3, 
        String param4, 
        String param5, 
        String param6,
        String param7
    ) {
        System.debug('Too many params');
    }
    
    // VIOLAZIONE: Complessità ciclomatica troppo alta + If annidati troppo profondi
    public String complexMethod(Integer value, Boolean flag1, Boolean flag2, Boolean flag3) {
        String result = '';
        
        if (value > 0) {
            if (flag1) {
                if (flag2) {
                    if (flag3) {
                        if (value > 10) {
                            if (value > 20) {
                                if (value > 30) {
                                    result = 'Very high';
                                } else {
                                    result = 'High';
                                }
                            } else {
                                result = 'Medium';
                            }
                        } else {
                            result = 'Low';
                        }
                    } else {
                        result = 'Flag3 false';
                    }
                } else {
                    result = 'Flag2 false';
                }
            } else {
                result = 'Flag1 false';
            }
        } else {
            result = 'Negative';
        }
        
        return result;
    }
    
    // VIOLAZIONE: SOQL Injection (Security)
    public List<Account> unsafeQuery(String accountName) {
        // PERICOLOSO: String concatenation in SOQL
        String query = 'SELECT Id, Name FROM Account WHERE Name = \'' + accountName + '\'';
        return Database.query(query);
    }
    
    // VIOLAZIONE: SOQL in loop (Performance)
    public void soqlInLoop(List<String> accountIds) {
        for (String accId : accountIds) {
            // MALE: Query dentro un loop
            List<Account> accs = [SELECT Id FROM Account WHERE Id = :accId];
            System.debug(accs);
        }
    }
    
    // VIOLAZIONE: DML in loop (Performance)
    public void dmlInLoop(List<Account> accounts) {
        for (Account acc : accounts) {
            acc.Name = acc.Name + '_Updated';
            // MALE: DML dentro un loop
            update acc;
        }
    }
    
    // VIOLAZIONE: Metodo troppo lungo + Troppe istruzioni
    public void veryLongMethod() {
        Integer a = 1;
        Integer b = 2;
        Integer c = 3;
        Integer d = 4;
        Integer e = 5;
        Integer f = 6;
        Integer g = 7;
        Integer h = 8;
        Integer i = 9;
        Integer j = 10;
        
        System.debug('Line 1');
        System.debug('Line 2');
        System.debug('Line 3');
        System.debug('Line 4');
        System.debug('Line 5');
        System.debug('Line 6');
        System.debug('Line 7');
        System.debug('Line 8');
        System.debug('Line 9');
        System.debug('Line 10');
        System.debug('Line 11');
        System.debug('Line 12');
        System.debug('Line 13');
        System.debug('Line 14');
        System.debug('Line 15');
        System.debug('Line 16');
        System.debug('Line 17');
        System.debug('Line 18');
        System.debug('Line 19');
        System.debug('Line 20');
        System.debug('Line 21');
        System.debug('Line 22');
        System.debug('Line 23');
        System.debug('Line 24');
        System.debug('Line 25');
        System.debug('Line 26');
        System.debug('Line 27');
        System.debug('Line 28');
        System.debug('Line 29');
        System.debug('Line 30');
        
        if (a > 0) {
            System.debug('a positive');
        }
        if (b > 0) {
            System.debug('b positive');
        }
        if (c > 0) {
            System.debug('c positive');
        }
        if (d > 0) {
            System.debug('d positive');
        }
        if (e > 0) {
            System.debug('e positive');
        }
    }
    
    // VIOLAZIONE: Catch generico senza gestione
    public void poorExceptionHandling() {
        try {
            Integer result = 10 / 0;
        } catch (Exception e) {
            // MALE: catch generico senza fare nulla
        }
    }
    
    // VIOLAZIONE: Hardcoded credentials (Security)
    private static final String PASSWORD = 'MyPassword123';
    private static final String API_KEY = 'sk_live_1234567890';
    
    // VIOLAZIONE: Avoid Debug Statements
    public void debugEverywhere(String value) {
        System.debug('Starting method');
        System.debug('Value is: ' + value);
        System.debug('Processing...');
        System.debug('Almost done...');
        System.debug('Finished!');
    }
    
    // VIOLAZIONE: Avoid empty statements + Code smell
    public void emptyMethod() {
        // Metodo vuoto
    }
    
    // VIOLAZIONE: Avoid empty if
    public void emptyIfStatement(Boolean condition) {
        if (condition) {
            // Non fa nulla
        }
    }
    
    // VIOLAZIONE: Avoid using hardcoded IDs
    public Account getAccountById() {
        return [SELECT Id, Name FROM Account WHERE Id = '001xx000003DGbXXXX' LIMIT 1];
    }
    
    // VIOLAZIONE: No null check (NullPointerException potential)
    public Integer getAccountNameLength(Account acc) {
        // Può generare NullPointerException se acc o acc.Name è null
        return acc.Name.length();
    }
    
    // VIOLAZIONE: Avoid global modifiers (se non necessario)
    global class InnerGlobalClass {
        global void globalMethod() {
            System.debug('Global method');
        }
    }
    
    // VIOLAZIONE: Variabili con nomi di una sola lettera
    public void badVariableNames() {
        Integer x = 10;
        String s = 'test';
        Boolean b = true;
        
        for (Integer i = 0; i < 100; i++) {
            Integer y = i * 2;
            String t = 'value' + y;
        }
    }
    
    // VIOLAZIONE: Avoid public fields
    public String publicField = 'Should be private with getter/setter';
    
    // VIOLAZIONE: Missing Apex doc comment
    public void noDocumentation(String param1, Integer param2) {
        // Metodo senza documentazione
        System.debug(param1 + param2);
    }
}
