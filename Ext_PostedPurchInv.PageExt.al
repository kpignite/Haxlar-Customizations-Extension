pageextension 50009 Ext_PostedPurchInv extends "Posted Purchase Invoice"
{
    layout
    {
        // Add changes to page layout here
        addafter("No.")
        {
            field("PO Status"; Rec."PO Status")
            {
                ApplicationArea = all;
            }
            field("Production Date"; Rec."Production Date")
            {
                ApplicationArea = all;
            }
        }
        addafter(Corrective)
        {
            field("Purchase Comment"; Rec."Purchase Comment")
            {
                ApplicationArea = all;
                MultiLine = true;
            }
        }
    }
    var myInt: Integer;
}
