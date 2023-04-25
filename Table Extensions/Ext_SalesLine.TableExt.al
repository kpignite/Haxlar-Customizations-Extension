tableextension 50004 Ext_SalesLine extends "Sales Line"
{
    fields
    {
        field(50000; Cstm_Description; Text[200])
        {
        }
        field(50001; RevisionMaterialsFinish; Text[100])
        {
            DataClassification = ToBeClassified;
        }
        modify("No.")
        {
            trigger OnAfterValidate()
            var
                Item: Record Item;
            begin
                Validate(Cstm_Description, Description);
            end;
        }
    }
    var
        myInt: Integer;
}
