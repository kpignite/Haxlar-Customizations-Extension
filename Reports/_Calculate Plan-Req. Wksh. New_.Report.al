report 50074 "Calculate Plan-Req. Wksh. New"
{
    // LS  = changes made by LS Retail
    // LS-9959 GH - Remove Inventory Masks or unused code.
    // 
    // Omar  (22-07-21): Copy from report 699 and upadet on it to add location code (FAWAZ-000249)
    Caption = 'Calculate Plan - Req. Wksh.';
    ProcessingOnly = true;

    dataset
    {
        dataitem(Item; Item)
        {
            DataItemTableView = SORTING("Low-Level Code")WHERE(Type=CONST(Inventory));
            RequestFilterFields = "No.", "Search Description";

            trigger OnAfterGetRecord()
            begin
                //LS -
                IF Item.Blocked THEN CurrReport.SKIP;
                //LS +
                IF Counter MOD 5 = 0 THEN Window.UPDATE(1, "No.");
                Counter:=Counter + 1;
                IF SkipPlanningForItemOnReqWksh(Item)THEN CurrReport.SKIP;
                PlanningAssignment.SETRANGE("Item No.", "No.");
                ReqLine.LOCKTABLE;
                ActionMessageEntry.LOCKTABLE;
                PurchReqLine.SETRANGE("No.", "No.");
                PurchReqLine.MODIFYALL("Accept Action Message", FALSE);
                PurchReqLine.DELETEALL(TRUE);
                ReqLineExtern.SETRANGE(Type, ReqLine.Type::Item);
                ReqLineExtern.SETRANGE("No.", "No.");
                IF ReqLineExtern.FIND('-')THEN REPEAT ReqLineExtern.DELETE(TRUE);
                    UNTIL ReqLineExtern.NEXT = 0;
                //LS-9959//
                // //LS -
                // InvtProfileOffsetting.SetUseISDistribution(gUseLSDistribution);
                // InvtProfileOffsetting.SetInvMaskNo(InvMask."Seq. No.");
                // //LS +
                //LS-9959//
                InvtProfileOffsetting.SetParm(UseForecast, ExcludeForecastBefore, CurrWorksheetType);
                InvtProfileOffsetting.SetReqWorksheetAllLoc(LocationCode, TRUE); //em
                InvtProfileOffsetting.CalculatePlanFromWorksheet(Item, MfgSetup, CurrTemplateName, CurrWorksheetName, FromDate, ToDate, TRUE, RespectPlanningParm);
                IF PlanningAssignment.FIND('-')THEN REPEAT IF PlanningAssignment."Latest Date" <= ToDate THEN BEGIN
                            PlanningAssignment.Inactive:=TRUE;
                            PlanningAssignment.MODIFY;
                        END;
                    UNTIL PlanningAssignment.NEXT = 0;
                COMMIT;
            end;
            trigger OnPreDataItem()
            begin
                SETRANGE("Location Filter", LocationCode); //Omar
                SKU.SETCURRENTKEY("Item No.");
                COPYFILTER("Variant Filter", SKU."Variant Code");
                COPYFILTER("Location Filter", SKU."Location Code");
                COPYFILTER("Variant Filter", PlanningAssignment."Variant Code");
                COPYFILTER("Location Filter", PlanningAssignment."Location Code");
                PlanningAssignment.SETRANGE(Inactive, FALSE);
                PlanningAssignment.SETRANGE("Net Change Planning", TRUE);
                ReqLineExtern.SETCURRENTKEY(Type, "No.", "Variant Code", "Location Code");
                COPYFILTER("Variant Filter", ReqLineExtern."Variant Code");
                COPYFILTER("Location Filter", ReqLineExtern."Location Code");
                PurchReqLine.SETCURRENTKEY(Type, "No.", "Variant Code", "Location Code", "Sales Order No.", "Planning Line Origin", "Due Date");
                PurchReqLine.SETRANGE(Type, PurchReqLine.Type::Item);
                COPYFILTER("Variant Filter", PurchReqLine."Variant Code");
                COPYFILTER("Location Filter", PurchReqLine."Location Code");
                PurchReqLine.SETFILTER("Worksheet Template Name", ReqWkshTemplateFilter);
                PurchReqLine.SETFILTER("Journal Batch Name", ReqWkshFilter);
            end;
        }
    }
    requestpage
    {
        SaveValues = true;

        layout
        {
            area(content)
            {
                group(Options)
                {
                    Caption = 'Options';

                    field(StartingDate; FromDate)
                    {
                        ApplicationArea = all;
                        Caption = 'Starting Date';
                        ToolTip = 'Specifies the date to use for new orders. This date is used to evaluate the inventory.';
                    }
                    field(EndingDate; ToDate)
                    {
                        ApplicationArea = all;
                        Caption = 'Ending Date';
                        ToolTip = 'Specifies the date where the planning period ends. Demand is not included beyond this date.';
                    }
                    field(UseForecast; UseForecast)
                    {
                        ApplicationArea = all;
                        Caption = 'Use Forecast';
                        TableRelation = "Production Forecast Name".Name;
                        ToolTip = 'Specifies a forecast that should be included as demand when running the planning batch job.';
                    }
                    field(ExcludeForecastBefore; ExcludeForecastBefore)
                    {
                        ApplicationArea = all;
                        Caption = 'Exclude Forecast Before';
                        ToolTip = 'Specifies how much of the selected forecast to include, by entering a date before which forecast demand is not included.';
                    }
                    field(RespectPlanningParm; RespectPlanningParm)
                    {
                        ApplicationArea = all;
                        Caption = 'Respect Planning Parameters for Supply Triggered by Safety Stock';
                        ToolTip = 'Specifies that planning lines triggered by safety stock will respect the following planning parameters: Reorder Point, Reorder Quantity, Reorder Point, and Maximum Inventory in addition to all order modifiers. If you do not select this check box, planning lines triggered by safety stock will only cover the exact demand quantity.';
                    }
                    field(LocationCode; LocationCode)
                    {
                        ApplicationArea = all;
                        Caption = 'Location Code';
                        TableRelation = Location;
                    }
                }
            }
        }
        actions
        {
        }
        trigger OnOpenPage()
        begin
            MfgSetup.GET;
            UseForecast:=MfgSetup."Current Production Forecast";
        end;
    }
    labels
    {
    }
    trigger OnPreReport()
    var
        ProductionForecastEntry: Record "Production Forecast Entry";
    begin
        Counter:=0;
        IF FromDate = 0D THEN ERROR(Text002);
        IF ToDate = 0D THEN ERROR(Text003);
        PeriodLength:=ToDate - FromDate + 1;
        IF PeriodLength <= 0 THEN ERROR(Text004);
        //Omar+
        IF Item.GETFILTER("Location Filter") <> '' THEN ERROR(Text009, Item.FIELDCAPTION("Location Filter"));
        IF LocationCode = '' THEN ERROR(Text008);
        Item.SETRANGE("Location Filter", LocationCode);
        //Omar-
        IF(Item.GETFILTER("Variant Filter") <> '') AND (MfgSetup."Current Production Forecast" <> '')THEN BEGIN
            ProductionForecastEntry.SETRANGE("Production Forecast Name", MfgSetup."Current Production Forecast");
            Item.COPYFILTER("No.", ProductionForecastEntry."Item No.");
            IF MfgSetup."Use Forecast on Locations" THEN Item.COPYFILTER("Location Filter", ProductionForecastEntry."Location Code");
            IF NOT ProductionForecastEntry.ISEMPTY THEN ERROR(Text005);
        END;
        ReqLine.SETRANGE("Worksheet Template Name", CurrTemplateName);
        ReqLine.SETRANGE("Journal Batch Name", CurrWorksheetName);
        Window.OPEN(Text006 + Text007);
    end;
    var Text002: Label 'Enter a starting date.';
    Text003: Label 'Enter an ending date.';
    Text004: Label 'The ending date must not be before the order date.';
    Text005: Label 'You must not use a variant filter when calculating MPS from a forecast.';
    Text006: Label 'Calculating the plan...\\';
    Text007: Label 'Item No.  #1##################';
    ReqLine: Record "Requisition Line";
    ActionMessageEntry: Record "Action Message Entry";
    ReqLineExtern: Record "Requisition Line";
    PurchReqLine: Record "Requisition Line";
    SKU: Record "Stockkeeping Unit";
    PlanningAssignment: Record "Planning Assignment";
    MfgSetup: Record "Manufacturing Setup";
    InvtProfileOffsetting: Codeunit "Inventory Profile Off Cstm";
    Window: Dialog;
    CurrWorksheetType: Option Requisition, Planning;
    PeriodLength: Integer;
    CurrTemplateName: Code[10];
    CurrWorksheetName: Code[10];
    FromDate: Date;
    ToDate: Date;
    ReqWkshTemplateFilter: Code[50];
    ReqWkshFilter: Code[50];
    Counter: Integer;
    UseForecast: Code[10];
    ExcludeForecastBefore: Date;
    RespectPlanningParm: Boolean;
    "---LSR---": Integer;
    gOrderDate: Date;
    gToDate: Date;
    LocationCode: Code[10];
    Text008: Label 'You must specify Location Code';
    Text009: Label 'You must not specify %1.\Specify Location Code instead';
    procedure SetTemplAndWorksheet(TemplateName: Code[10]; WorksheetName: Code[10])
    begin
        CurrTemplateName:=TemplateName;
        CurrWorksheetName:=WorksheetName;
    end;
    procedure InitializeRequest(StartDate: Date; EndDate: Date)
    begin
        FromDate:=StartDate;
        ToDate:=EndDate;
    end;
    local procedure SkipPlanningForItemOnReqWksh(Item: Record "Item"): Boolean var
        SkipPlanning: Boolean;
        IsHandled: Boolean;
    begin
        IsHandled:=FALSE;
        SkipPlanning:=FALSE;
        OnBeforeSkipPlanningForItemOnReqWksh(Item, SkipPlanning, IsHandled);
        IF IsHandled THEN EXIT(SkipPlanning);
        IF(CurrWorksheetType = CurrWorksheetType::Requisition) AND (Item."Replenishment System" = Item."Replenishment System"::Purchase) AND (Item."Reordering Policy" <> Item."Reordering Policy"::" ")THEN EXIT(FALSE);
        SKU.SETRANGE(SKU."Item No.", Item."No.");
        IF SKU.FIND('-')THEN REPEAT IF(CurrWorksheetType = CurrWorksheetType::Requisition) AND (SKU."Replenishment System" IN[SKU."Replenishment System"::Purchase, SKU."Replenishment System"::Transfer]) AND (SKU."Reordering Policy" <> SKU."Reordering Policy"::" ")THEN EXIT(FALSE);
            UNTIL SKU.NEXT = 0;
        SkipPlanning:=TRUE;
        OnAfterSkipPlanningForItemOnReqWksh(Item, SkipPlanning);
        EXIT(SkipPlanning);
    end;
    [IntegrationEvent(false, false)]
    local procedure OnAfterSkipPlanningForItemOnReqWksh(Item: Record "Item"; var SkipPlanning: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforeSkipPlanningForItemOnReqWksh(Item: Record "Item"; var SkipPlanning: Boolean; var IsHandled: Boolean)
    begin
    end;
}
