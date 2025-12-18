/**
 * @description       : 
 * @author            : michele11.argentino@nttdata.com
 * @group             : 
 * @last modified on  : 12-18-2025
 * @last modified by  : michele11.argentino@nttdata.com
**/
public with sharing class KHC_CaseClass {
    public KHC_CaseClass() {
        Integer x=1;
        if(x==1){
            if(x==1){
                 if(x==1){
                     if(x==1){
                        x=2;
                        System.debug(1);
                        System.debug(1);
                    }
                }
            }
        }else{
            x=3;
            System.debug(2);
        }
    }

    public static void test1(){
        Integer x =1;
    }

    public static void test2(){
        Integer x =1; 
    }
    public static void test3(){
        Integer x =1;
    }
    public static void test4(){
        Integer x =1;
    }
}
