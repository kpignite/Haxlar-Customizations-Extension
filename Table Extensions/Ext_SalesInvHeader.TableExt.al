tableextension 50009 Ext_SalesInvHeader extends "Sales Invoice Header"
{
    fields
    {
        // Add changes to table fields here
        field(50000; "Sales Comment"; Text[2048])
        {
            DataClassification = ToBeClassified;
        }
    }
    var myInt: Integer;
}
