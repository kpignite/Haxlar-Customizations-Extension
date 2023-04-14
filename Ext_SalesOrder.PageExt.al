pageextension 50010 Ext_SalesOrder extends "Sales Order"
{
    layout
    {
        // Add changes to page layout here
        addbefore("Sell-to Customer No.")
        {
            field("SO No."; Rec."No.")
            {
                ApplicationArea = all;
            }
        }
        addafter(Status)
        {
            field("Sales Comment"; Rec."Sales Comment")
            {
                ApplicationArea = all;
                MultiLine = true;
            }
        }
    }
    var myInt: Integer;
}
