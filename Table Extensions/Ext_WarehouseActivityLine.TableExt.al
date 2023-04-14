tableextension 50000 Ext_WarehouseActivityLine extends "Warehouse Activity Line"
{
    fields
    {
        // Add changes to table fields here
        field(50000; dimension; Code[20])
        {
        }
        field(50001; "Carton/Pallet"; Code[20])
        {
        }
    }
    var myInt: Integer;
}
