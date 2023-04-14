reportextension 50000 Ext_PickingList extends "Picking List"
{
    dataset
    {
        // Add changes to dataitems and columns here
        add("Warehouse Activity Line")
        {
            column(dimension; dimension)
            {
            }
            column(Weight; Weight)
            {
            }
            column(Carton_Pallet; "Carton/Pallet")
            {
            }
        }
    }
    requestpage
    {
    // Add changes to the requestpage here
    }
}
