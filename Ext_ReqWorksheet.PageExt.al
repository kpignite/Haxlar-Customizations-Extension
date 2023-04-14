pageextension 50015 Ext_ReqWorksheet extends "Req. Worksheet"
{
    actions
    {
        // Add changes to page actions here
        addafter(CalculatePlan)
        {
            action(CalculatePlanAllLoctions)
            {
                ApplicationArea = all;
                Caption = 'Calculate Plan All Locations';
                Ellipsis = true;
                Image = CalculatePlan;
                Promoted = true;
                PromotedIsBig = true;
                ToolTip = 'Use a batch job to help you calculate a supply plan for items and stockkeeping units that have the Replenishment System field set to Purchase or Transfer.';

                trigger OnAction()
                begin
                    Clear(CalculatePlanReqWkshNew);
                    Clear(ReqLine);
                    CalculatePlanReqWkshNew.SetTemplAndWorksheet(Rec."Worksheet Template Name", Rec."Journal Batch Name");
                    CalculatePlanReqWkshNew.RUNMODAL;
                end;
            }
        }
    }
    var myInt: Integer;
    CalculatePlanReqWkshNew: Report "Calculate Plan-Req. Wksh. New";
    CaclulateSOPlan: Report CalculateSOPlan;
    ReqLine: Record "Requisition Line";
    PurchLine: Record "Purchase Line";
}
