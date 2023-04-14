tableextension 50003 Ext_PurchasInveLine extends "Purch. Inv. Line"
{
    fields
    {
        // Add changes to table fields here
        field(50000; ETD; Date)
        {
        }
        field(50001; Cstm_Description; Text[200])
        {
        }
        field(50002; Notes; Text[200])
        {
        }
        field(50003; Remarks; Text[200])
        {
        }
    }
    var myInt: Integer;
}
