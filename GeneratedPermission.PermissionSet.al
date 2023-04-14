permissionset 50000 GeneratedPermission
{
    Assignable = true;
    Permissions = tabledata "Replenishment Sub Locations"=RIMD,
        table "Replenishment Sub Locations"=X,
        report "Calculate Plan-Req. Wksh. New"=X,
        report CalculateSOPlan=X,
        report ItemsbByPO=X,
        report ItemsbBySO=X,
        report ItemsByLocation=X,
        codeunit "Inventory Profile Off Cstm"=X,
        page PurchaseLine=X,
        page "Replenishment Sub Locations"=X,
        tabledata IncoTerms=RIMD,
        table IncoTerms=X,
        report ItemSoDetailReport=X,
        page IncoTermsList=X;
}
