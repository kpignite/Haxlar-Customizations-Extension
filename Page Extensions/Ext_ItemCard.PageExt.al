pageextension 50018 Ext_ItemCard extends "Item Card"
{
    layout
    {
        // Add changes to page layout here
        modify("No.")
        {
            ShowMandatory = true;
        }
        modify(Description)
        {
            ShowMandatory = true;
        }
        modify(Type)
        {
            ShowMandatory = true;
        }
        modify("Base Unit of Measure")
        {
            ShowMandatory = true;
        }
        modify("Item Category Code")
        {
            ShowMandatory = true;
        }
        modify("Costing Method")
        {
            ShowMandatory = true;
        }
        modify("Unit Cost")
        {
            ShowMandatory = true;
        }
        modify("Gen. Prod. Posting Group")
        {
            ShowMandatory = true;
        }
        modify("Tax Group Code")
        {
            ShowMandatory = true;
        }
        modify("Inventory Posting Group")
        {
            ShowMandatory = true;
        }
        modify("Unit Price")
        {
            ShowMandatory = true;
        }
        modify("Sales Unit of Measure")
        {
            ShowMandatory = true;
        }
        modify("Order Tracking Policy")
        {
            ShowMandatory = true;
        }
        modify("Purch. Unit of Measure")
        {
            ShowMandatory = true;
        }
        modify("Replenishment System")
        {
            ShowMandatory = true;
        }
        modify("Assembly Policy")
        {
            ShowMandatory = true;
        }
        modify("Item Tracking Code")
        {
            ShowMandatory = true;
        }
    }
    trigger OnNewRecord(BelowxRex: Boolean)
    var
        myInt: Integer;
    begin
        Rec."Item Tracking Code":='LOT';
        Rec."Lot Nos.":='LOT';
    end;
    var myInt: Integer;
}
