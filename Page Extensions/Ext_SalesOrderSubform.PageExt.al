pageextension 50004 Ext_SalesOrderSubform extends "Sales Order Subform"
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
            }
        }
    }
    var myInt: Integer;
}
