public class ImportFile {
    
    //mystuff 
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

    //constructor
    public ImportFile(){
        object_map = new Map<String,Schema.sObjectType>(); 
        List<Schema.SObjectType> gd = Schema.getGlobalDescribe().Values();    
        objects = new List<SelectOption>();
            for(Schema.SObjectType f : gd){
                if(f.getDescribe().isAccessible() && (f.getDescribe().isCreateable() || f.getDescribe().isUpdateable())){
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
                if(sobj_field.getDescribe().isCreateable() || sobj_field.getDescribe().isUpdateable()){
                    fields.add(new SelectOption(s,s)); 
                }
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
        mappings = new List<FieldMapping>(); 
        for(String s : field_mapping.keySet()){
            mappings.add(new FieldMapping(select_object,field_mapping.get(s),field_indexes.get(s)));
        }
        mappings.sort(); 

        return null;
    }

    public PageReference doInsert(){
        List<SObject> insertObjects = this.getDMLObjects();
        system.debug('objects are ' + insertObjects);
        List<Database.SaveResult> errors = Database.Insert(insertObjects);

        if(!errors.isEmpty()){
            has_errors = true;
            upload_errors = new List<ImportError>(); 
            for(Database.SaveResult sr : errors){
                upload_errors.add(new ImportError(sr));
            }
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
            }
            dmlObjects.add(so);
        }
        return dmlObjects; 
   }

    public class FieldMapping implements Comparable{
        public String obj {get;set;} 
        public Integer col_index {get;set;}
        public String field_name {get;set;}

        public FieldMapping(String obj,String field_name,Integer idx){
            this.obj = obj; 
            this.field_name = field_name; 
            this.col_index = idx; 
        }

        public Integer compareTo(Object comp){
            FieldMapping compMapping = (FieldMapping)comp; 
            if (this.col_index == compMapping.col_index) return 0; 
            if (this.col_index > compMapping.col_index) return 1; 
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