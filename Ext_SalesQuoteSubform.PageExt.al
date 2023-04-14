pageextension 50017 Ext_SalesQuoteSubform extends "Sales Quote Subform"
{
    layout
    {
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
                ShowMandatory = true;
            }
            field(RevisionMaterialsFinish; Rec.RevisionMaterialsFinish)
            {
                ApplicationArea = all;
                Caption = 'Revision/Material/Finish';
                MultiLine = true;
                ShowMandatory = true;
            }
        }
        modify("No.")
        {
            ShowMandatory = true;
        }
        modify(Type)
        {
            ShowMandatory = true;
        }
        modify("Location Code")
        {
            ShowMandatory = true;
        }
        modify(Quantity)
        {
            ShowMandatory = true;
        }
        modify("Qty. to Assemble to Order")
        {
            Visible = false;
        }
        modify("Unit of Measure")
        {
            ShowMandatory = true;
        }
        modify("Unit Price")
        {
            ShowMandatory = true;
        }
        modify("Tax Area Code")
        {
            Visible = false;
        }
        modify("Tax Group Code")
        {
            ShowMandatory = true;
        }
        modify("Line Discount %")
        {
            Visible = false;
        }
        modify("Subtotal Excl. VAT")
        {
            Visible = false;
        }
        modify("Amount Including VAT")
        {
            Visible = false;
        }
        modify("Line Amount")
        {
            Visible = false;
        }
    }
    trigger OnNewRecord(BelowxRec: Boolean)
    var
        myInt: Integer;
    begin
        Rec.Type:=Rec.Type::Item;
    end;
    var myInt: Integer;
}
