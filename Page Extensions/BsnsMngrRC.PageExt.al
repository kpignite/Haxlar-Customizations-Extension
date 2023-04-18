pageextension 50006 BsnsMngrRC extends "Business Manager Role Center"
{
    actions
    {
        addlast(sections)
        {
            group("Haxlar Reports")
            {
                action("Item by Location Report")
                {
                    RunObject = report ItemsByLocation;
                    ApplicationArea = All;
                }
                action("Item by PO Report")
                {
                    RunObject = report ItemsbByPO;
                    ApplicationArea = All;
                }
                action("Item by SO Report")
                {
                    RunObject = report ItemsbBySO;
                    ApplicationArea = All;
                }
                action("Item SO Detail Report")
                {
                    RunObject = report ItemSoDetailReport;
                    ApplicationArea = All;
                }
                action("Customer Open Sales Order Report")
                {
                    RunObject = report "Customer Open Sales Order";
                    ApplicationArea = All;
                }
            }
        }
    }
}
