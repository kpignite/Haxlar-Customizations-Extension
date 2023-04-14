pageextension 50007 Ext_PurchOrder extends "Purchase Order"
{
    layout
    {
        // Add changes to page layout here
        addbefore("Buy-from Vendor No.")
        {
            field("PO No."; Rec."No.")
            {
                ApplicationArea = all;
            }
        }
        addafter("Document Date")
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
        addafter(Status)
        {
            field("Purchase Comment"; Rec."Purchase Comment")
            {
                ApplicationArea = all;
                MultiLine = true;
            }
            field("IncoTerms"; Rec."Inco Terms")
            {
                ApplicationArea = all;
                Caption = 'IncoTerms';
            }
        }
    }
    var myInt: Integer;
}
