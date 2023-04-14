pageextension 50000 Ext_O365Activities extends "O365 Activities"
{
    layout
    {
        // Add changes to page layout here
        addafter("Ongoing Purchases")
        {
            cuegroup(Haxlar_Cues)
            {
                field("Transit-Partially Shipped"; Rec."Transit-Partially Shipped")
                {
                    ApplicationArea = Basic, Suite;
                    DrillDownPageID = "Purchase Lines";
                    ToolTip = 'Transit Partially Shipped Qty';
                }
                field("Transit Not Shipped"; Rec."Transit Not Shipped")
                {
                    ApplicationArea = Basic, Suite;
                    DrillDownPageID = "Purchase Lines";
                    ToolTip = 'Transit Not Shipped Qty';
                }
                field("Parts Ready"; Rec."Parts Ready")
                {
                    ApplicationArea = Basic, Suite;
                    DrillDownPageID = "Purchase Order List";
                    ToolTip = 'Parts Ready';
                }
                field("Awaiting Pickup"; Rec."Awaiting Pickup")
                {
                    ApplicationArea = Basic, Suite;
                    DrillDownPageID = "Purchase Order List";
                    ToolTip = 'Parts Ready';
                }
            }
        }
    }
    var myInt: Integer;
}
