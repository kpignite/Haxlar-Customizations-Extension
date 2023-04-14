pageextension 50001 Ext_InvtPickSubform extends "Invt. Pick Subform"
{
    layout
    {
        // Add changes to page layout here
        addafter(Quantity)
        {
            field(dimension; Rec.dimension)
            {
                ApplicationArea = all;
            }
            field(Weight; Rec.Weight)
            {
                ApplicationArea = all;
            }
            field("Carton/Pallet"; Rec."Carton/Pallet")
            {
                ApplicationArea = all;
            }
        }
    }
    var myInt: Integer;
}
