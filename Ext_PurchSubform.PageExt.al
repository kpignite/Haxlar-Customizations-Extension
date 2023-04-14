pageextension 50003 Ext_PurchSubform extends "Purchase Order Subform"
{
    layout
    {
        // Add changes to page layout here
        addafter("Expected Receipt Date")
        {
            field(ETA; Rec.ETA)
            {
                ApplicationArea = all;
            }
        }
        modify(Description)
        {
            Visible = false;
        }
        addafter("No.")
        {
            field(Cstm_Description; Rec.Cstm_Description)
            {
                ApplicationArea = all;
                Caption = 'Description';
                MultiLine = true;
            }
            field(Notes; Rec.Notes)
            {
                ApplicationArea = all;
                Caption = 'Notes';
            }
            field(Remarks; Rec.Remarks)
            {
                ApplicationArea = all;
                Caption = 'Remarks';
            }
        }
    }
    var myInt: Integer;
}
