pageextension 50002 Ext_PurchaseLine extends "Purchase Lines"
{
    layout
    {
        // Add changes to page layout here
        addafter("Buy-from Vendor No.")
        {
            field("Vendor Name"; Vendor.Name)
            {
                ApplicationArea = all;
            }
            field("Shipment Code"; PurchHeader."Shipment Method Code")
            {
                ApplicationArea = all;
            }
        }
        addafter(Quantity)
        {
            field("Quantity Received"; Rec."Quantity Received")
            {
                ApplicationArea = all;
            }
        }
        addafter("Expected Receipt Date")
        {
            field(ETA; Rec.ETA)
            {
                ApplicationArea = all;
            }
        }
    }
    trigger OnAfterGetRecord()
    var
        myInt: Integer;
    begin
        IF Vendor.Get(Rec."Buy-from Vendor No.")then;
        PurchHeader.SetFilter("No.", Rec."Document No.");
        if PurchHeader.FindFirst()then;
    end;
    var Vendor: Record Vendor;
    PurchHeader: Record "Purchase Header";
}
