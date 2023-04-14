pageextension 50008 Ext_PurchOrderList extends "Purchase Order List"
{
    layout
    {
        // Add changes to page layout here
        addafter("No.")
        {
            field("Vendor Invoice No."; Rec."Vendor Invoice No.")
            {
                ApplicationArea = all;
            }
            field("Production Date"; Rec."Production Date")
            {
                ApplicationArea = all;
            }
        }
    }
    var myInt: Integer;
}
