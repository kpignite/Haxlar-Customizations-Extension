tableextension 50008 Ext_SalesHeader extends "Sales Header"
{
    fields
    {
        // Add changes to table fields here
        field(50000; "Sales Comment"; Text[2048])
        {
            DataClassification = ToBeClassified;
        }
        field(50001; "Tooling Lead Time"; Text[30])
        {
            DataClassification = ToBeClassified;
        }
        field(50002; "Sample Lead Time"; Text[30])
        {
            DataClassification = ToBeClassified;
        }
        field(50003; "Production Lead Time"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(50004; "Transit Lead Time"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(50005; "Quoted Currency"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(50006; "Tooling Payment Terms"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(50007; "Production Terms"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(50008; "PPAP Requirement"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(50009; "Technical Review"; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        field(50010; "UserName"; Text[30])
        {
            DataClassification = ToBeClassified;
        }
        field(50011; "UserEmail"; Text[30])
        {
            DataClassification = ToBeClassified;
        }
        field(50012; "UserPhone"; Text[30])
        {
            DataClassification = ToBeClassified;
        }
        field(50013; IncoTerms; Text[30])
        {
            DataClassification = ToBeClassified;
            TableRelation = IncoTerms.Description;
            ValidateTableRelation = false;
        }
        field(50014; RevisionMaterialsFinish; Text[30])
        {
            DataClassification = ToBeClassified;
        }
    }
    var
        myInt: Integer;
}
