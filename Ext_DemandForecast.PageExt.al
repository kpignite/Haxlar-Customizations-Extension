pageextension 50013 Ext_DemandForecast extends "Demand Forecast Card"
{
    actions
    {
        // Add changes to page actions here
        addafter("Next Column")
        {
            action(CalculateTotalSales)
            {
                ApplicationArea = all;
                Caption = 'Calculate Sales All Locations';
                Image = CalculatePlan;
                Promoted = true;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    Clear(CaclulateSOPlan);
                    //CaclulateSOPlan.SetLocationFilter();
                    CaclulateSOPlan.RunModal();
                    CurrPage.Update(true);
                end;
            }
        }
    }
    var myInt: Integer;
    CaclulateSOPlan: Report CalculateSOPlan;
}
