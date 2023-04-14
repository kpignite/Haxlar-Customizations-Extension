pageextension 50012 MyExtension extends "Purch. Invoice Subform"
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
