tableextension 50001 Ext_ActivitiesCues extends "Activities Cue"
{
    fields
    {
        // Add changes to table fields here
        field(50000; "Transit-Partially Shipped"; Decimal)
        {
            CalcFormula = Sum("Purchase Line"."Outstanding Quantity" WHERE("Document Type"=FILTER(Order), "Outstanding Quantity"=FILTER(<>0), "Location Code"=filter('TRNST-ORDR')));
            Caption = 'Transit-Partially Shipped';
            Editable = false;
            FieldClass = FlowField;
        }
        field(50001; "Transit Not Shipped"; Decimal)
        {
            CalcFormula = Sum("Purchase Line"."Outstanding Quantity" WHERE("Document Type"=FILTER(Order), "Quantity Received"=FILTER(=0), "Location Code"=filter('TRNST-ORDR')));
            Caption = 'Transit Not Shipped';
            Editable = false;
            FieldClass = FlowField;
        }
        field(50002; "Parts Ready"; Integer)
        {
            CalcFormula = count("Purchase Header" WHERE("PO Status"=filter("Parts Complete")));
            Caption = 'Parts Ready';
            Editable = false;
            FieldClass = FlowField;
        }
        field(50003; "Awaiting Pickup"; Integer)
        {
            CalcFormula = count("Purchase Header" WHERE("PO Status"=filter("Awaiting Pickup")));
            Caption = 'Awaiting Pickup';
            Editable = false;
            FieldClass = FlowField;
        }
    }
    var myInt: Integer;
}
