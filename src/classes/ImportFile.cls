public class ImportFile {
	
	//mystuff 
    public Map<String,String> field_mapping {get;set;}
    public List<FieldMapping> mappings {get;set;}
    public List<String> col_headers {get;set;}
    public List<SelectOption> objects {get;set;}
    public List<SelectOption> fields {get;set;}
    public Set<String> selected_fields {get;set;}
    public String csv_file {get;set;}
    public String select_object {get;set;}
    public Blob contentFile {get;set;}
    public String nameFile {get;set;}
    public String temp {get;set;}


    //class only stuff
    public Map<String,Integer> field_indexes {get;set;}


    //constructor
    public ImportFile(){
        List<Schema.SObjectType> gd = Schema.getGlobalDescribe().Values();    
        objects = new List<SelectOption>();
            for(Schema.SObjectType f : gd){
                objects.add(new SelectOption(f.getDescribe().getLabel(),f.getDescribe().getLabel()));
            }
    }
    public PageReference mapFields(){
        Map <String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map<String,Schema.SObjectField> field_map = schemaMap.get('importtest__c').getDescribe().fields.getMap();
        col_headers = new List<String>(); 
         temp = contentFile.toString().split('\n')[0]; 
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
            fields.add(new SelectOption(s,s)); 
        }

        return null;
    }       

    public PageReference saveMapping(){
    	mappings = new List<FieldMapping>(); 
    	for(String s : field_mapping.keySet()){
    		mappings.add(new FieldMapping('importtest__c',field_mapping.get(s),field_indexes.get(s)));
    	}
    	mappings.sort(); 

    	return null;
    }

    public PageReference doInsert(){
    	List<SObject> insertObjects = this.getDMLObjects();
    	List<Database.SaveResult> errors = Database.Insert(insertObjects);

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
	   	for(Integer x = 1; x > csv_rows.size(); x++){
	    	SObject so = Schema.getGlobalDescribe().get('importtest__c').newSObject();
	    	Integer y = 0; 
	    	for(String cell : csv_rows[x].split(',')){
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
}