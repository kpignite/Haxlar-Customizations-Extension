pageextension 50011 Ext_PstdSalesInv extends "Posted Sales Invoice"
{
    layout
    {
        // Add changes to page layout here
        addafter(Corrective)
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
