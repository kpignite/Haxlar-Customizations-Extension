tableextension 50007 Ext_PurchInvHeader extends "Purch. Inv. Header"
{
    fields
    {
        // Add changes to table fields here
        field(50000; "PO Status"; Option)
        {
            DataClassification = ToBeClassified;
            OptionMembers = , "Parts Complete", "Awaiting Pickup";
        }
        field(50001; "Production Date"; Date)
        {
            DataClassification = ToBeClassified;
        }
        field(50002; "Purchase Comment"; Text[2048])
        {
            DataClassification = ToBeClassified;
        }
        field(50003; "Inco Terms"; Text[30])
        {
            DataClassification = ToBeClassified;
        }
    }
    var myInt: Integer;
}
