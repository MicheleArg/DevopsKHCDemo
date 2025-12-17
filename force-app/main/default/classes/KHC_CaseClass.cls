/**
 * @description       : 
 * @author            : michele11.argentino@nttdata.com
 * @group             : 
 * @last modified on  : 12-17-2025
 * @last modified by  : michele11.argentino@nttdata.com
**/
public with sharing class KHC_CaseClass {
    public KHC_CaseClass() {
        Integer x=0;
        if(x=1){
            x=2;
            System.debug(1);
        }else{
            x=3;
            System.debug(2);
        }
    }
}