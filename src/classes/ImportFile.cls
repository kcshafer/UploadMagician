public class ImportFile {
    
    //mystuff 
    public Map<String, FieldMapping> temp_map {get;set;}
    public Map<String,String> field_mapping {get;set;}
    public List<FieldMapping> mappings {get;set;}
    public List<String> col_headers {get;set;}
    public List<SelectOption> objects {get;set;}
    public List<SelectOption> fields {get;set;}
    public List<ImportError> upload_errors {get;set;}
    public Set<String> selected_fields {get;set;}
    public String csv_file {get;set;}
    public String select_object {get;set;}
    public Blob contentFile {get;set;}
    public String nameFile {get;set;}
    public String temp {get;set;}
    public string temp2 {get;set;}


    //boolean render properties 
    public Boolean renderDMLButtons {get;set;} //might not need this 
    public Boolean renderGenerateMapping {get;set;}
    public Boolean isCreateable {get;set;}
    public Boolean isUpdateable {get;set;}
    public Boolean has_errors {get;set;}

    //class only stuff
    public Map<String,Integer> field_indexes {get;set;}
    public Map<String,Schema.sObjectType> object_map;
    public UploadMagician__c main_settings; //root settings file 
    public Set<String> excludefields_main = new Set<String>(); 
    public Set<String> excludeobjs_main = new Set<String>(); 

    //constructor
    public ImportFile(){
        main_settings = UploadMagician__c.getInstance('main'); 
        List<String> excfields_temp = main_settings.Exclude_Fields__c.split(','); 
        List<String> excobjs_temp = main_settings.Exclude_Objects__c.split(','); 
        excludeobjs_main.addAll(excobjs_temp);
        excludefields_main.addAll(excfields_temp);
        object_map = new Map<String,Schema.sObjectType>(); 
        List<Schema.SObjectType> gd = Schema.getGlobalDescribe().Values();    
        objects = new List<SelectOption>();
            for(Schema.SObjectType f : gd){
                if((!excludeobjs_main.contains(f.getDescribe().getName())) && f.getDescribe().isAccessible() && (f.getDescribe().isCreateable() || f.getDescribe().isUpdateable())){
                    object_map.put(f.getDescribe().getName(),f);
                    objects.add(new SelectOption(f.getDescribe().getName(),f.getDescribe().getLabel()));
                }
            }
        objects.sort(); 

    }

    public PageReference mapFields(){
        if(contentFile != null){
            Schema.sObjectType sobj = object_map.get(select_object);
            Schema.DescribeSObjectResult sobj_desc = sobj.getDescribe(); 
            isCreateable = sobj_desc.isCreateable(); 
            isUpdateable = sobj_desc.isUpdateable(); 
            Map <String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
            Map<String,Schema.SObjectField> field_map = schemaMap.get(select_object).getDescribe().fields.getMap();
            col_headers = new List<String>(); 
            temp2 = contentFile.toString(); 
            temp2 = temp2.split('\n')[0];
             temp = (contentFile.toString().split('\n'))[0]; 
            col_headers = temp.split(',');  
            field_mapping = new Map<String,String>();
            fields = new List<SelectOption>(); 
            field_indexes = new Map<String,Integer>(); 
            Integer x = 0; 
            for(String s : col_headers){
                field_mapping.put(s,'');
                field_indexes.put(s,x);
                x++; 
            }
            system.debug('kc is ' + field_mapping); 
            for(String s : field_map.keySet()){
                Schema.SObjectField sobj_field = field_map.get(s);
                if((!excludefields_main.contains(s)) && (sobj_field.getDescribe().isCreateable() || sobj_field.getDescribe().isUpdateable())){
                    fields.add(new SelectOption(s,s)); 
                }
            }
            mappings = new List<FieldMapping>(); 
            temp_map = new Map<String,FieldMapping>();
            for(String s : field_mapping.keySet()){
                temp_map.put(s,new FieldMapping(select_object,field_mapping.get(s),field_indexes.get(s),s,fields));
            }
        }
        else{
            ApexPages.Message error = new ApexPages.Message(ApexPages.severity.WARNING,'File Is Empty');
            ApexPages.addMessage(error); 
        }
        renderGenerateMapping = true; 
        return null;
    }       

    public PageReference saveMapping(){
        /*mappings = new List<FieldMapping>(); 
        for(String s : field_mapping.keySet()){
            mappings.add(new FieldMapping(select_object,field_mapping.get(s),field_indexes.get(s)));
        }*/
        mappings.sort(); 

        return null;
    }

    public PageReference doInsert(){
        try{
            List<SObject> insertObjects = this.getDMLObjects();
            system.debug('objects are ' + insertObjects);
            List<Database.SaveResult> errors = Database.Insert(insertObjects,false);

            if(!errors.isEmpty()){
                has_errors = true;
                upload_errors = new List<ImportError>(); 
                for(Database.SaveResult sr : errors){
                    upload_errors.add(new ImportError(sr));
                }
            }
        }
        catch(Exception e){
            ApexPages.Message error = new ApexPages.Message(ApexPages.severity.WARNING,'Bad field value');
            ApexPages.addMessage(error); 
        }

        return null; 
    }

   public PageReference doUpdate(){
        List<SObject> updateObjects = this.getDMLObjects(); 
        List<Database.SaveResult> errors = Database.Update(updateObjects); 

        return null; 
   }

   //get a list of sobject to use for insert and update ops 
   private List<SObject> getDMLObjects(){
        List<SObject> dmlObjects = new List<SObject>(); 
        List<String> csv_rows = contentFile.toString().split('\n'); 
        system.debug('rows are ' + csv_rows.size()); 
        for(Integer x = 1; x < csv_rows.size(); x++){
            SObject so = Schema.getGlobalDescribe().get(select_object).newSObject();
            Integer y = 0; 
            system.debug('kc is ' + csv_rows[x].split(','));
            for(String cell : csv_rows[x].split(',')){
                system.debug('cell is ' + cell);
                so.put(mappings[y].field_name,cell); 
                y++; 
            }
            dmlObjects.add(so);
        }
        return dmlObjects; 
   }

    public class FieldMapping implements Comparable{
        public String obj {get;set;} 
        public Integer col_index {get;set;}
        public String field_name {get;set;}
        public String col_header {get;set;}
        public String default_val {get;set;}
        public List<SelectOption> options {get;set;}
        public List<Levenshtein> levs; 

        public FieldMapping(String obj,String field_name,Integer idx,String col_head, List<SelectOption> options){
            this.obj = obj; 
            this.field_name = field_name; 
            this.col_index = idx;
            this.options = options; 
            this.col_header = col_head;
            this.matchField(); 
        }

        //uses the levenshtein distance theory to calculate a matching score between a csv header and fields in salesforce
        private void matchField(){
            Map<String,Integer> matching_scores = new Map<String,Integer>(); 
            levs = new List<Levenshtein>(); 
            for(SelectOption so : this.options){
                levs.add(new Levenshtein(so.getValue(),this.col_header));
            }
            system.debug('list levs are ' + levs);
            levs.sort(); 
            default_val = levs[0].field_name; 
            this.field_name = levs[0].field_name;
        }
        public Integer compareTo(Object comp){
            FieldMapping compMapping = (FieldMapping)comp; 
            if (this.col_index == compMapping.col_index) return 0; 
            if (this.col_index > compMapping.col_index) return 1; 
            return -1; 
        }
    }

    public class Levenshtein implements Comparable{
        public Integer score; 
        public String field_name; 
        public String col_header; 

        public Levenshtein(String field_name,String col_head){
            this.field_name = field_name; 
            this.col_header = col_head; 
            this.score = this.field_name.getLevenshteinDistance(this.col_header); 
        }

        public Integer compareTo(Object comp){
            Levenshtein lev = (Levenshtein)comp;
            if(this.score == lev.score) return 0; 
            if(this.score > lev.score) return 1;
            return -1; 
        }
    }

    public class ImportError{
        public Id id {get;set;}
        public List<String> error_messages {get;set;}
        public Boolean status {get;set;}

        public ImportError(Database.SaveResult sr){
            this.id = sr.getId(); 
            this.status = sr.isSuccess(); 
            this.error_messages = new List<String>(); 
            for(Database.Error err : sr.getErrors()){
                //TODO: use the getFields() method to use with highlighting issues fields, provide more info etc. 
                this.error_messages.add(err.getMessage());
            }
        }
    }      
}