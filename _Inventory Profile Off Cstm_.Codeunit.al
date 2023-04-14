codeunit 50074 "Inventory Profile Off Cstm"
{
    // Omar  (01-07-23): 
    Permissions = TableData 337=id,
        TableData 5410=rmd;

    trigger OnRun()
    begin
    end;
    var ReqLine: Record "Requisition Line";
    ItemLedgEntry: Record "Item Ledger Entry";
    TempSKU: Record "Stockkeeping Unit" temporary;
    TempTransferSKU: Record "Stockkeeping Unit" temporary;
    ManufacturingSetup: Record "Manufacturing Setup";
    InvtSetup: Record "Inventory Setup";
    ReservEntry: Record "Reservation Entry";
    TempTrkgReservEntry: Record "Reservation Entry" temporary;
    TempItemTrkgEntry: Record "Reservation Entry" temporary;
    ActionMsgEntry: Record "Action Message Entry";
    TempPlanningCompList: Record "Planning Component" temporary;
    DummyInventoryProfileTrackBuffer: Record "Inventory Profile Track Buffer";
    CustomizedCalendarChange: Record "Customized Calendar Change";
    CalendarManagement: Codeunit "Calendar Management";
    LeadTimeMgt: Codeunit "Lead-Time Management";
    PlngLnMgt: Codeunit "Planning Line Management";
    PlanningTransparency: Codeunit "Planning Transparency";
    UOMMgt: Codeunit "Unit of Measure Management";
    BucketSize: DateFormula;
    ExcludeForecastBefore: Date;
    ScheduleDirection: Option Forward, Backward;
    PlanningLineStage: Option " ", "Line Created", "Routing Created", Exploded, Obsolete;
    SurplusType: Option "None", Forecast, BlanketOrder, SafetyStock, ReorderPoint, MaxInventory, FixedOrderQty, MaxOrder, MinOrder, OrderMultiple, DampenerQty, PlanningFlexibility, Undefined, EmergencyOrder;
    CurrWorksheetType: Option Requisition, Planning;
    DampenerQty: Decimal;
    FutureSupplyWithinLeadtime: Decimal;
    LineNo: Integer;
    DampenersDays: Integer;
    BucketSizeInDays: Integer;
    CurrTemplateName: Code[10];
    CurrWorksheetName: Code[10];
    CurrForecast: Code[10];
    PlanMRP: Boolean;
    SpecificLotTracking: Boolean;
    SpecificSNTracking: Boolean;
    Text001: Label 'Assertion failed: %1.';
    UseParm: Boolean;
    PlanningResilicency: Boolean;
    Text002: Label 'The %1 from ''%2'' to ''%3'' does not exist.';
    Text003: Label 'The %1 for %2 %3 %4 %5 does not exist.';
    Text004: Label '%1 must not be %2 in %3 %4 %5 %6 when %7 is %8.';
    Text005: Label '%1 must not be %2 in %3 %4 when %5 is %6.';
    Text006: Label '%1: The projected available inventory is %2 on the planning starting date %3.';
    Text007: Label '%1: The projected available inventory is below %2 %3 on %4.';
    Text008: Label '%1: The %2 %3 is before the work date %4.';
    Text009: Label '%1: The %2 of %3 %4 is %5.';
    Text010: Label 'The projected inventory %1 is higher than the overflow level %2 on %3.';
    PlanToDate: Date;
    OverflowLevel: Decimal;
    ExceedROPqty: Decimal;
    NextStateTxt: Label 'StartOver,MatchDates,MatchQty,CreateSupply,ReduceSupply,CloseDemand,CloseSupply,CloseLoop';
    NextState: Option StartOver, MatchDates, MatchQty, CreateSupply, ReduceSupply, CloseDemand, CloseSupply, CloseLoop;
    LotAccumulationPeriodStartDate: Date;
    ReqWorksheetLocFilter: Code[1000];
    ReqWorksheetLocationCode: Code[10];
    ReqWorksheetAllLoc: Boolean;
    procedure CalculatePlanFromWorksheet(var Item: Record "Item"; ManufacturingSetup2: Record "Manufacturing Setup"; TemplateName: Code[10]; WorksheetName: Code[10]; OrderDate: Date; ToDate: Date; MRPPlanning: Boolean; RespectPlanningParm: Boolean)
    var
        InventoryProfile: array[2]of Record "Inventory Profile" temporary;
    begin
        OnBeforeCalculatePlanFromWorksheet(Item, ManufacturingSetup2, TemplateName, WorksheetName, OrderDate, ToDate, MRPPlanning, RespectPlanningParm);
        PlanToDate:=ToDate;
        InitVariables(InventoryProfile[1], ManufacturingSetup2, Item, TemplateName, WorksheetName, MRPPlanning);
        DemandToInvtProfile(InventoryProfile[1], Item, ToDate);
        OrderDate:=ForecastConsumption(InventoryProfile[1], Item, OrderDate, ToDate);
        BlanketOrderConsump(InventoryProfile[1], Item, ToDate);
        SupplytoInvProfile(InventoryProfile[1], Item, ToDate);
        UnfoldItemTracking(InventoryProfile[1], InventoryProfile[2]);
        FindCombination(InventoryProfile[1], InventoryProfile[2], Item);
        PlanItem(InventoryProfile[1], InventoryProfile[2], OrderDate, ToDate, RespectPlanningParm);
        OnCalculatePlanFromWorksheetOnAfterPlanItem(CurrTemplateName, CurrWorksheetName, Item, ReqLine, TempTrkgReservEntry);
        CommitTracking;
        OnAfterCalculatePlanFromWorksheet(Item);
    end;
    local procedure InitVariables(var InventoryProfile: Record "Inventory Profile"; ManufacturingSetup2: Record "Manufacturing Setup"; Item: Record "Item"; TemplateName: Code[10]; WorksheetName: Code[10]; MRPPlanning: Boolean)
    var
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        ManufacturingSetup:=ManufacturingSetup2;
        InvtSetup.GET;
        CurrTemplateName:=TemplateName;
        CurrWorksheetName:=WorksheetName;
        InventoryProfile.RESET;
        InventoryProfile.DELETEALL;
        TempSKU.RESET;
        TempSKU.DELETEALL;
        CLEAR(TempSKU);
        TempTransferSKU.RESET;
        TempTransferSKU.DELETEALL;
        CLEAR(TempTransferSKU);
        TempTrkgReservEntry.RESET;
        TempTrkgReservEntry.DELETEALL;
        TempItemTrkgEntry.RESET;
        TempItemTrkgEntry.DELETEALL;
        PlanMRP:=MRPPlanning;
        IF Item."Item Tracking Code" <> '' THEN BEGIN
            ItemTrackingCode.GET(Item."Item Tracking Code");
            SpecificLotTracking:=ItemTrackingCode."Lot Specific Tracking";
            SpecificSNTracking:=ItemTrackingCode."SN Specific Tracking";
        END
        ELSE
        BEGIN
            SpecificLotTracking:=FALSE;
            SpecificSNTracking:=FALSE;
        END;
        LineNo:=0; // Global variable
        PlanningTransparency.SetTemplAndWorksheet(CurrTemplateName, CurrWorksheetName);
    end;
    local procedure CreateTempSKUForLocation(ItemNo: Code[20]; LocationCode: Code[10])
    begin
        TempSKU.INIT;
        TempSKU."Item No.":=ItemNo;
        TransferPlanningParameters(TempSKU);
        TempSKU."Location Code":=LocationCode;
        TempSKU.INSERT;
    end;
    local procedure DemandToInvtProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; ToDate: Date)
    var
        CopyOfItem: Record "Item";
        IsHandled: Boolean;
    begin
        IsHandled:=FALSE;
        OnBeforeDemandToInvProfile(InventoryProfile, Item, IsHandled);
        IF IsHandled THEN EXIT;
        InventoryProfile.SETCURRENTKEY("Line No.");
        CopyOfItem.COPY(Item);
        Item.SETRANGE("Date Filter", 0D, ToDate);
        TransSalesLineToProfile(InventoryProfile, Item);
        TransServLineToProfile(InventoryProfile, Item);
        TransJobPlanningLineToProfile(InventoryProfile, Item);
        TransProdOrderCompToProfile(InventoryProfile, Item);
        TransAsmLineToProfile(InventoryProfile, Item);
        TransPlanningCompToProfile(InventoryProfile, Item);
        TransTransReqLineToProfile(InventoryProfile, Item, ToDate);
        TransShptTransLineToProfile(InventoryProfile, Item);
        OnAfterDemandToInvProfile(InventoryProfile, Item, TempItemTrkgEntry, LineNo);
        Item.COPY(CopyOfItem);
    end;
    local procedure SupplytoInvProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; ToDate: Date)
    var
        CopyOfItem: Record "Item";
    begin
        InventoryProfile.RESET;
        ItemLedgEntry.RESET;
        InventoryProfile.SETCURRENTKEY("Line No.");
        CopyOfItem.COPY(Item);
        Item.SETRANGE("Date Filter");
        OnBeforeSupplyToInvProfile(InventoryProfile, Item, ToDate, TempItemTrkgEntry, LineNo);
        TransItemLedgEntryToProfile(InventoryProfile, Item);
        TransReqLineToProfile(InventoryProfile, Item, ToDate);
        TransPurchLineToProfile(InventoryProfile, Item, ToDate);
        TransProdOrderToProfile(InventoryProfile, Item, ToDate);
        TransAsmHeaderToProfile(InventoryProfile, Item, ToDate);
        TransRcptTransLineToProfile(InventoryProfile, Item, ToDate);
        OnAfterSupplyToInvProfile(InventoryProfile, Item, ToDate, TempItemTrkgEntry, LineNo);
        Item.COPY(CopyOfItem);
    end;
    local procedure InsertSupplyProfile(var InventoryProfile: Record "Inventory Profile"; ToDate: Date)
    begin
        IF InventoryProfile.IsSupply THEN BEGIN
            IF InventoryProfile."Due Date" > ToDate THEN InventoryProfile."Planning Flexibility":=InventoryProfile."Planning Flexibility"::None;
            InventoryProfile.INSERT;
        END
        ELSE IF InventoryProfile."Due Date" <= ToDate THEN BEGIN
                InventoryProfile.ChangeSign;
                InventoryProfile."Planning Flexibility":=InventoryProfile."Planning Flexibility"::None;
                InventoryProfile.INSERT;
            END;
    end;
    local procedure TransSalesLineToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item")
    var
        SalesLine: Record "Sales line";
        OK: Boolean;
    begin
        //Omar IF SalesLine.FindLinesWithItemToPlan(Item,SalesLine."Document Type"::Order) THEN
        //Omar+
        OK:=SalesLine.FindLinesWithItemToPlan(Item, SalesLine."Document Type"::Order);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            SalesLine.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=SalesLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF SalesLine."Shipment Date" <> 0D THEN BEGIN
                    InventoryProfile.INIT;
                    InventoryProfile."Line No.":=NextLineNo;
                    InventoryProfile.TransferFromSalesLine(SalesLine, TempItemTrkgEntry);
                    IF InventoryProfile.IsSupply THEN InventoryProfile.ChangeSign;
                    InventoryProfile."MPS Order":=TRUE;
                    //Omar+
                    IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                    //Omar-
                    InventoryProfile.INSERT;
                END;
            UNTIL SalesLine.NEXT = 0;
        //Omar IF SalesLine.FindLinesWithItemToPlan(Item,SalesLine."Document Type"::"Return Order") THEN
        //Omar+
        OK:=SalesLine.FindLinesWithItemToPlan(Item, SalesLine."Document Type"::"Return Order");
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            SalesLine.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=SalesLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF SalesLine."Shipment Date" <> 0D THEN BEGIN
                    InventoryProfile.INIT;
                    InventoryProfile."Line No.":=NextLineNo;
                    InventoryProfile.TransferFromSalesLine(SalesLine, TempItemTrkgEntry);
                    IF InventoryProfile.IsSupply THEN InventoryProfile.ChangeSign;
                    //Omar+
                    IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                    //Omar-
                    InventoryProfile.INSERT;
                END;
            UNTIL SalesLine.NEXT = 0;
    end;
    local procedure TransServLineToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item")
    var
        ServLine: Record "Service Line";
        OK: Boolean;
    begin
        //Omar IF ServLine.FindLinesWithItemToPlan(Item) THEN
        //Omar+
        OK:=ServLine.FindLinesWithItemToPlan(Item);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            ServLine.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=ServLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF ServLine."Needed by Date" <> 0D THEN BEGIN
                    InventoryProfile.INIT;
                    InventoryProfile."Line No.":=NextLineNo;
                    InventoryProfile.TransferFromServLine(ServLine, TempItemTrkgEntry);
                    IF InventoryProfile.IsSupply THEN InventoryProfile.ChangeSign;
                    //Omar+
                    IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                    //Omar-
                    InventoryProfile.INSERT;
                END;
            UNTIL ServLine.NEXT = 0;
    end;
    local procedure TransJobPlanningLineToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item")
    var
        JobPlanningLine: Record "Job Planning Line";
        OK: Boolean;
    begin
        //Omar IF JobPlanningLine.FindLinesWithItemToPlan(Item) THEN
        //Omar+
        OK:=JobPlanningLine.FindLinesWithItemToPlan(Item);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            JobPlanningLine.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=JobPlanningLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF JobPlanningLine."Planning Date" <> 0D THEN BEGIN
                    InventoryProfile.INIT;
                    InventoryProfile."Line No.":=NextLineNo;
                    InventoryProfile.TransferFromJobPlanningLine(JobPlanningLine, TempItemTrkgEntry);
                    IF InventoryProfile.IsSupply THEN InventoryProfile.ChangeSign;
                    //Omar+
                    IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                    //Omar-
                    InventoryProfile.INSERT;
                END;
            UNTIL JobPlanningLine.NEXT = 0;
    end;
    local procedure TransProdOrderCompToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item")
    var
        ProdOrderComp: Record "Prod. Order Component";
        OK: Boolean;
    begin
        //Omar IF ProdOrderComp.FindLinesWithItemToPlan(Item,TRUE) THEN
        //Omar+
        OK:=ProdOrderComp.FindLinesWithItemToPlan(Item, TRUE);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            ProdOrderComp.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=ProdOrderComp.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF ProdOrderComp."Due Date" <> 0D THEN BEGIN
                    ReqLine.SetRefFilter(ReqLine."Ref. Order Type"::"Prod. Order", ProdOrderComp.Status.AsInteger(), ProdOrderComp."Prod. Order No.", ProdOrderComp."Prod. Order Line No.");
                    ReqLine.SETRANGE("Operation No.", '');
                    IF NOT ReqLine.FINDFIRST THEN BEGIN
                        InventoryProfile.INIT;
                        InventoryProfile."Line No.":=NextLineNo;
                        InventoryProfile.TransferFromComponent(ProdOrderComp, TempItemTrkgEntry);
                        IF InventoryProfile.IsSupply THEN InventoryProfile.ChangeSign;
                        //Omar+
                        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                        //Omar-
                        InventoryProfile.INSERT;
                    END;
                END;
            UNTIL ProdOrderComp.NEXT = 0;
    end;
    local procedure TransPlanningCompToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item")
    var
        PlanningComponent: Record "Planning Component";
        OK: Boolean;
    begin
        IF NOT PlanMRP THEN EXIT;
        //Omar IF PlanningComponent.FindLinesWithItemToPlan(Item) THEN
        //Omar+
        OK:=PlanningComponent.FindLinesWithItemToPlan(Item);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            PlanningComponent.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=PlanningComponent.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF PlanningComponent."Due Date" <> 0D THEN BEGIN
                    InventoryProfile.INIT;
                    InventoryProfile."Line No.":=NextLineNo;
                    InventoryProfile."Item No.":=Item."No.";
                    InventoryProfile.TransferFromPlanComponent(PlanningComponent, TempItemTrkgEntry);
                    IF InventoryProfile.IsSupply THEN InventoryProfile.ChangeSign;
                    //Omar+
                    IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                    //Omar-
                    InventoryProfile.INSERT;
                END;
            UNTIL PlanningComponent.NEXT = 0;
    end;
    local procedure TransAsmLineToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item")
    var
        AsmHeader: Record "Assembly Header";
        AsmLine: Record "Assembly Line";
        RemRatio: Decimal;
        OK: Boolean;
    begin
        //Omar IF AsmLine.FindLinesWithItemToPlan(Item,AsmLine."Document Type"::Order) THEN
        //Omar+
        OK:=AsmLine.FindItemToPlanLines(Item, AsmLine."Document Type"::Order);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            AsmLine.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=AsmLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF AsmLine."Due Date" <> 0D THEN BEGIN
                    ReqLine.SetRefFilter(ReqLine."Ref. Order Type"::Assembly, AsmLine."Document Type".AsInteger(), AsmLine."Document No.", 0);
                    ReqLine.SETRANGE("Operation No.", '');
                    IF NOT ReqLine.FINDFIRST THEN InsertAsmLineToProfile(InventoryProfile, AsmLine, 1);
                END;
            UNTIL AsmLine.NEXT = 0;
        //Omar IF AsmLine.FindLinesWithItemToPlan(Item,AsmLine."Document Type"::"Blanket Order") THEN
        //Omar+
        OK:=AsmLine.FindItemToPlanLines(Item, AsmLine."Document Type"::"Blanket Order");
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            AsmLine.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=AsmLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF AsmLine."Due Date" <> 0D THEN BEGIN
                    ReqLine.SetRefFilter(ReqLine."Ref. Order Type"::Assembly, AsmLine."Document Type".AsInteger(), AsmLine."Document No.", 0);
                    ReqLine.SETRANGE("Operation No.", '');
                    IF NOT ReqLine.FINDFIRST THEN BEGIN
                        AsmHeader.GET(AsmLine."Document Type", AsmLine."Document No.");
                        RemRatio:=(AsmHeader."Quantity (Base)" - CalcSalesOrderQty(AsmLine)) / AsmHeader."Quantity (Base)";
                        InsertAsmLineToProfile(InventoryProfile, AsmLine, RemRatio);
                    END;
                END;
            UNTIL AsmLine.NEXT = 0;
    end;
    local procedure TransTransReqLineToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; ToDate: Date)
    var
        TransferReqLine: Record "Requisition Line";
    begin
        TransferReqLine.SETCURRENTKEY("Replenishment System", Type, "No.", "Variant Code", "Transfer-from Code", "Transfer Shipment Date");
        TransferReqLine.SETRANGE("Replenishment System", TransferReqLine."Replenishment System"::Transfer);
        TransferReqLine.SETRANGE(Type, TransferReqLine.Type::Item);
        TransferReqLine.SETRANGE("No.", Item."No.");
        Item.COPYFILTER("Location Filter", TransferReqLine."Transfer-from Code");
        Item.COPYFILTER("Variant Filter", TransferReqLine."Variant Code");
        TransferReqLine.SETFILTER("Transfer Shipment Date", '>%1&<=%2', 0D, ToDate);
        //Omar+
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN TransferReqLine.SETFILTER("Transfer-from Code", ReqWorksheetLocFilter);
        //Omar-
        IF TransferReqLine.FINDSET THEN REPEAT InventoryProfile.INIT;
                InventoryProfile."Line No.":=NextLineNo;
                InventoryProfile."Item No.":=Item."No.";
                InventoryProfile.TransferFromOutboundTransfPlan(TransferReqLine, TempItemTrkgEntry);
                IF InventoryProfile.IsSupply THEN InventoryProfile.ChangeSign;
                //Omar+
                IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                //Omar-
                InventoryProfile.INSERT;
            UNTIL TransferReqLine.NEXT = 0;
    end;
    local procedure TransShptTransLineToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item")
    var
        TransLine: Record "Transfer Line";
        FilterIsSetOnLocation: Boolean;
        OK: Boolean;
    begin
        FilterIsSetOnLocation:=Item.GETFILTER("Location Filter") <> '';
        //Omar IF TransLine.FindLinesWithItemToPlan(Item,FALSE,TRUE) THEN
        //Omar+
        OK:=TransLine.FindLinesWithItemToPlan(Item, FALSE, TRUE);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            TransLine.SETFILTER("Transfer-from Code", ReqWorksheetLocFilter);
            OK:=TransLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF TransLine."Shipment Date" <> 0D THEN BEGIN
                    InventoryProfile.INIT;
                    InventoryProfile."Line No.":=NextLineNo;
                    InventoryProfile."Item No.":=Item."No.";
                    InventoryProfile.TransferFromOutboundTransfer(TransLine, TempItemTrkgEntry);
                    IF InventoryProfile.IsSupply THEN InventoryProfile.ChangeSign;
                    IF FilterIsSetOnLocation THEN InventoryProfile."Transfer Location Not Planned":=TransferLocationIsFilteredOut(Item, TransLine);
                    //Omar+
                    IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                    //Omar-
                    SyncTransferDemandWithReqLine(InventoryProfile, TransLine."Transfer-to Code");
                    InventoryProfile.INSERT;
                END;
            UNTIL TransLine.NEXT = 0;
    end;
    local procedure TransItemLedgEntryToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item")
    var
        OK: Boolean;
    begin
        //Omar IF ItemLedgEntry.FindLinesWithItemToPlan(Item,FALSE) THEN
        //Omar+
        OK:=ItemLedgEntry.FindLinesWithItemToPlan(Item, FALSE);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            ItemLedgEntry.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=ItemLedgEntry.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT InventoryProfile.INIT;
                InventoryProfile."Line No.":=NextLineNo;
                InventoryProfile.TransferFromItemLedgerEntry(ItemLedgEntry, TempItemTrkgEntry);
                InventoryProfile."Due Date":=0D;
                IF NOT InventoryProfile.IsSupply THEN InventoryProfile.ChangeSign;
                //Omar+
                IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                //Omar-
                InventoryProfile.INSERT;
            UNTIL ItemLedgEntry.NEXT = 0;
    end;
    local procedure TransReqLineToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; ToDate: Date)
    var
        ReqLine: Record "Requisition Line";
        OK: Boolean;
    begin
        //Omar IF ReqLine.FindLinesWithItemToPlan(Item) THEN
        //Omar+
        OK:=ReqLine.FindLinesWithItemToPlan(Item);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            ReqLine.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=ReqLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF ReqLine."Due Date" <> 0D THEN BEGIN
                    InventoryProfile.INIT;
                    InventoryProfile."Line No.":=NextLineNo;
                    InventoryProfile."Item No.":=Item."No.";
                    InventoryProfile.TransferFromRequisitionLine(ReqLine, TempItemTrkgEntry);
                    //Omar+
                    IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                    //Omar-
                    InsertSupplyProfile(InventoryProfile, ToDate);
                END;
            UNTIL ReqLine.NEXT = 0;
    end;
    local procedure TransPurchLineToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; ToDate: Date)
    var
        PurchLine: Record "Purchase Line";
        OK: Boolean;
    begin
        //Omar IF PurchLine.FindLinesWithItemToPlan(Item,PurchLine."Document Type"::Order) THEN
        //Omar+
        OK:=PurchLine.FindLinesWithItemToPlan(Item, PurchLine."Document Type"::Order);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            PurchLine.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=PurchLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF PurchLine."Expected Receipt Date" <> 0D THEN IF PurchLine."Prod. Order No." = '' THEN InsertPurchLineToProfile(InventoryProfile, PurchLine, ToDate);
            UNTIL PurchLine.NEXT = 0;
        //Omar IF PurchLine.FindLinesWithItemToPlan(Item,PurchLine."Document Type"::"Return Order") THEN
        //Omar+
        OK:=PurchLine.FindLinesWithItemToPlan(Item, PurchLine."Document Type"::"Return Order");
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            PurchLine.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=PurchLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF PurchLine."Expected Receipt Date" <> 0D THEN IF PurchLine."Prod. Order No." = '' THEN InsertPurchLineToProfile(InventoryProfile, PurchLine, ToDate);
            UNTIL PurchLine.NEXT = 0;
    end;
    local procedure TransProdOrderToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; ToDate: Date)
    var
        ProdOrderLine: Record "Prod. Order Line";
        CapLedgEntry: Record "Capacity Ledger Entry";
        ProdOrderComp: Record "Prod. Order Component";
        OK: Boolean;
    begin
        //Omar IF ProdOrderLine.FindLinesWithItemToPlan(Item,TRUE) THEN
        //Omar+
        OK:=ProdOrderLine.FindLinesWithItemToPlan(Item, TRUE);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            ProdOrderLine.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=ProdOrderLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF ProdOrderLine."Due Date" <> 0D THEN BEGIN
                    InventoryProfile.INIT;
                    InventoryProfile."Line No.":=NextLineNo;
                    InventoryProfile.TransferFromProdOrderLine(ProdOrderLine, TempItemTrkgEntry);
                    IF(ProdOrderLine."Planning Flexibility" = ProdOrderLine."Planning Flexibility"::Unlimited) AND (ProdOrderLine.Status = ProdOrderLine.Status::Released)THEN BEGIN
                        CapLedgEntry.SETCURRENTKEY("Order Type", "Order No.");
                        CapLedgEntry.SETRANGE("Order Type", CapLedgEntry."Order Type"::Production);
                        CapLedgEntry.SETRANGE("Order No.", ProdOrderLine."Prod. Order No.");
                        ItemLedgEntry.RESET;
                        ItemLedgEntry.SETCURRENTKEY("Order Type", "Order No.");
                        ItemLedgEntry.SETRANGE("Order Type", ItemLedgEntry."Order Type"::Production);
                        ItemLedgEntry.SETRANGE("Order No.", ProdOrderLine."Prod. Order No.");
                        IF NOT(CapLedgEntry.ISEMPTY AND ItemLedgEntry.ISEMPTY)THEN InventoryProfile."Planning Flexibility":=InventoryProfile."Planning Flexibility"::None
                        ELSE
                        BEGIN
                            ProdOrderComp.SETRANGE(Status, ProdOrderLine.Status);
                            ProdOrderComp.SETRANGE("Prod. Order No.", ProdOrderLine."Prod. Order No.");
                            ProdOrderComp.SETRANGE("Prod. Order Line No.", ProdOrderLine."Line No.");
                            ProdOrderComp.SETFILTER("Qty. Picked (Base)", '>0');
                            IF NOT ProdOrderComp.ISEMPTY THEN InventoryProfile."Planning Flexibility":=InventoryProfile."Planning Flexibility"::None;
                        END;
                    END;
                    //Omar+
                    IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                    //Omar-
                    InsertSupplyProfile(InventoryProfile, ToDate);
                END;
            UNTIL ProdOrderLine.NEXT = 0;
    end;
    local procedure TransAsmHeaderToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; ToDate: Date)
    var
        AsmHeader: Record "Assembly Header";
        OK: Boolean;
    begin
        //Omar IF AsmHeader.FindLinesWithItemToPlan(Item,AsmHeader."Document Type"::Order) THEN
        //Omar+
        OK:=AsmHeader.FindItemToPlanLines(Item, AsmHeader."Document Type"::Order);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            AsmHeader.SETFILTER("Location Code", ReqWorksheetLocFilter);
            OK:=AsmHeader.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF AsmHeader."Due Date" <> 0D THEN BEGIN
                    InventoryProfile.INIT;
                    InventoryProfile."Line No.":=NextLineNo;
                    InventoryProfile.TransferFromAsmHeader(AsmHeader, TempItemTrkgEntry);
                    IF InventoryProfile."Finished Quantity" > 0 THEN InventoryProfile."Planning Flexibility":=InventoryProfile."Planning Flexibility"::None;
                    //Omar+
                    IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                    //Omar-
                    InsertSupplyProfile(InventoryProfile, ToDate);
                END;
            UNTIL AsmHeader.NEXT = 0;
    end;
    local procedure TransRcptTransLineToProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; ToDate: Date)
    var
        TransLine: Record "Transfer Line";
        WhseEntry: Record "Warehouse Entry";
        FilterIsSetOnLocation: Boolean;
        OK: Boolean;
    begin
        FilterIsSetOnLocation:=Item.GETFILTER("Location Filter") <> '';
        //Omar IF TransLine.FindLinesWithItemToPlan(Item,TRUE,TRUE) THEN
        //Omar+
        OK:=TransLine.FindLinesWithItemToPlan(Item, TRUE, TRUE);
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            TransLine.SETFILTER("Transfer-to Code", ReqWorksheetLocFilter);
            OK:=TransLine.FIND('-');
        END;
        IF OK THEN //Omar-
 REPEAT IF TransLine."Receipt Date" <> 0D THEN BEGIN
                    InventoryProfile.INIT;
                    InventoryProfile."Line No.":=NextLineNo;
                    InventoryProfile.TransferFromInboundTransfer(TransLine, TempItemTrkgEntry);
                    IF TransLine."Planning Flexibility" = TransLine."Planning Flexibility"::Unlimited THEN IF(InventoryProfile."Finished Quantity" > 0) OR (TransLine."Quantity Shipped" > 0) OR (TransLine."Derived From Line No." > 0)THEN InventoryProfile."Planning Flexibility":=InventoryProfile."Planning Flexibility"::None
                        ELSE
                        BEGIN
                            WhseEntry.SetSourceFilter(DATABASE::"Transfer Line", 0, InventoryProfile."Source ID", InventoryProfile."Source Ref. No.", TRUE);
                            IF NOT WhseEntry.ISEMPTY THEN InventoryProfile."Planning Flexibility":=InventoryProfile."Planning Flexibility"::None;
                        END;
                    IF FilterIsSetOnLocation THEN InventoryProfile."Transfer Location Not Planned":=TransferLocationIsFilteredOut(Item, TransLine);
                    //Omar+
                    IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
                    //Omar-
                    InsertSupplyProfile(InventoryProfile, ToDate);
                    InsertTempTransferSKU(TransLine);
                END;
            UNTIL TransLine.NEXT = 0;
    end;
    local procedure TransferLocationIsFilteredOut(var Item: Record "Item"; var TransLine: Record "Transfer Line"): Boolean var
        TempTransLine: Record "Transfer Line" temporary;
    begin
        TempTransLine:=TransLine;
        TempTransLine.INSERT;
        Item.COPYFILTER("Location Filter", TempTransLine."Transfer-from Code");
        Item.COPYFILTER("Location Filter", TempTransLine."Transfer-to Code");
        //Omar+
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
            TempTransLine.SETFILTER("Transfer-from Code", ReqWorksheetLocFilter);
            TempTransLine.SETFILTER("Transfer-to Code", ReqWorksheetLocFilter);
        END;
        //Omar-
        EXIT(TempTransLine.ISEMPTY);
    end;
    local procedure InsertPurchLineToProfile(var InventoryProfile: Record "Inventory Profile"; PurchLine: Record "Purchase Line"; ToDate: Date)
    begin
        InventoryProfile.INIT;
        InventoryProfile."Line No.":=NextLineNo;
        InventoryProfile.TransferFromPurchaseLine(PurchLine, TempItemTrkgEntry);
        IF InventoryProfile."Finished Quantity" > 0 THEN InventoryProfile."Planning Flexibility":=InventoryProfile."Planning Flexibility"::None;
        //Omar+
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
        //Omar-
        InsertSupplyProfile(InventoryProfile, ToDate);
    end;
    local procedure InsertAsmLineToProfile(var InventoryProfile: Record "Inventory Profile"; AsmLine: Record "Assembly Line"; RemRatio: Decimal)
    begin
        InventoryProfile.INIT;
        InventoryProfile."Line No.":=NextLineNo;
        InventoryProfile.TransferFromAsmLine(AsmLine, TempItemTrkgEntry);
        IF RemRatio <> 1 THEN BEGIN
            InventoryProfile."Untracked Quantity":=ROUND(InventoryProfile."Untracked Quantity" * RemRatio, UOMMgt.QtyRndPrecision);
            InventoryProfile."Remaining Quantity (Base)":=InventoryProfile."Untracked Quantity";
        END;
        IF InventoryProfile.IsSupply THEN InventoryProfile.ChangeSign;
        //Omar+
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '') AND (ReqWorksheetLocationCode <> '')THEN InventoryProfile."Location Code":=ReqWorksheetLocationCode;
        //Omar-
        InventoryProfile.INSERT;
    end;
    local procedure ForecastConsumption(var DemandInvtProfile: Record "Inventory Profile"; var Item: Record "Item"; OrderDate: Date; ToDate: Date)UpdatedOrderDate: Date var
        CustomCalendarChange: Array[2]of Record "Customized Calendar Change";
        ForecastEntry: Record "Production Forecast Entry";
        ForecastEntry2: Record "Production Forecast Entry";
        NextForecast: Record "Production Forecast Entry";
        TotalForecastQty: Decimal;
        ReplenishmentLocation: Code[10];
        ForecastExist: Boolean;
        NextForecastExist: Boolean;
        ReplenishmentLocationFound: Boolean;
        ComponentForecast: Boolean;
        ComponentForecastFrom: Boolean;
    begin
        UpdatedOrderDate:=OrderDate;
        ComponentForecastFrom:=FALSE;
        IF NOT ManufacturingSetup."Use Forecast on Locations" THEN BEGIN
            ReplenishmentLocationFound:=FindReplishmentLocation(ReplenishmentLocation, Item);
            IF InvtSetup."Location Mandatory" AND NOT ReplenishmentLocationFound THEN ComponentForecastFrom:=TRUE;
            ForecastEntry.SETCURRENTKEY("Production Forecast Name", "Item No.", "Component Forecast", "Forecast Date", "Location Code");
        END
        ELSE
            ForecastEntry.SETCURRENTKEY("Production Forecast Name", "Item No.", "Location Code", "Forecast Date", "Component Forecast");
        ItemLedgEntry.RESET;
        ItemLedgEntry.SETCURRENTKEY("Item No.", Open, "Variant Code", Positive, "Location Code");
        DemandInvtProfile.SETCURRENTKEY("Item No.", "Variant Code", "Location Code", "Due Date");
        NextForecast.COPY(ForecastEntry);
        IF NOT UseParm THEN CurrForecast:=ManufacturingSetup."Current Production Forecast";
        ForecastEntry.SETRANGE("Production Forecast Name", CurrForecast);
        ForecastEntry.SETRANGE("Forecast Date", ExcludeForecastBefore, ToDate);
        ForecastEntry.SETRANGE("Item No.", Item."No.");
        ForecastEntry2.COPY(ForecastEntry);
        Item.COPYFILTER("Location Filter", ForecastEntry2."Location Code");
        //Omar+
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN ForecastEntry2.SETFILTER("Location Code", ReqWorksheetLocFilter);
        //Omar-
        FOR ComponentForecast:=ComponentForecastFrom TO TRUE DO BEGIN
            IF ComponentForecast THEN BEGIN
                ReplenishmentLocation:=ManufacturingSetup."Components at Location";
                IF InvtSetup."Location Mandatory" AND (ReplenishmentLocation = '')THEN EXIT;
            END;
            ForecastEntry.SETRANGE("Component Forecast", ComponentForecast);
            ForecastEntry2.SETRANGE("Component Forecast", ComponentForecast);
            IF ForecastEntry2.FIND('-')THEN REPEAT IF ManufacturingSetup."Use Forecast on Locations" THEN BEGIN
                        ForecastEntry2.SETRANGE("Location Code", ForecastEntry2."Location Code");
                        ItemLedgEntry.SETRANGE("Location Code", ForecastEntry2."Location Code");
                        DemandInvtProfile.SETRANGE("Location Code", ForecastEntry2."Location Code");
                    END
                    ELSE
                    BEGIN
                        Item.COPYFILTER("Location Filter", ForecastEntry2."Location Code");
                        Item.COPYFILTER("Location Filter", ItemLedgEntry."Location Code");
                        Item.COPYFILTER("Location Filter", DemandInvtProfile."Location Code");
                        //Omar+
                        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BEGIN
                            ForecastEntry2.SETFILTER("Location Code", ReqWorksheetLocFilter);
                            ItemLedgEntry.SETFILTER("Location Code", ReqWorksheetLocFilter);
                            DemandInvtProfile.SETFILTER("Location Code", ReqWorksheetLocFilter);
                        END;
                    //Omar-
                    END;
                    ForecastEntry2.FIND('+');
                    ForecastEntry2.COPYFILTER("Location Code", ForecastEntry."Location Code");
                    Item.COPYFILTER("Location Filter", ForecastEntry2."Location Code");
                    //Omar+
                    IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN ForecastEntry2.SETFILTER("Location Code", ReqWorksheetLocFilter);
                    //Omar-
                    ForecastExist:=CheckForecastExist(ForecastEntry, OrderDate, ToDate);
                    IF ForecastExist THEN REPEAT ForecastEntry.SETRANGE("Forecast Date", ForecastEntry."Forecast Date");
                            ForecastEntry.CALCSUMS("Forecast Quantity (Base)");
                            TotalForecastQty:=ForecastEntry."Forecast Quantity (Base)";
                            ForecastEntry.FIND('+');
                            NextForecast.COPYFILTERS(ForecastEntry);
                            NextForecast.SETRANGE("Forecast Date", ForecastEntry."Forecast Date" + 1, ToDate);
                            IF NOT NextForecast.FINDFIRST THEN NextForecast."Forecast Date":=ToDate + 1
                            ELSE
                                REPEAT NextForecast.SETRANGE("Forecast Date", NextForecast."Forecast Date");
                                    NextForecast.CALCSUMS("Forecast Quantity (Base)");
                                    IF NextForecast."Forecast Quantity (Base)" = 0 THEN BEGIN
                                        NextForecast.SETRANGE("Forecast Date", NextForecast."Forecast Date" + 1, ToDate);
                                        IF NOT NextForecast.FINDFIRST THEN NextForecast."Forecast Date":=ToDate + 1 END
                                    ELSE
                                        NextForecastExist:=TRUE UNTIL(NextForecast."Forecast Date" = ToDate + 1) OR NextForecastExist;
                            NextForecastExist:=FALSE;
                            ItemLedgEntry.SETRANGE("Item No.", Item."No.");
                            ItemLedgEntry.SETRANGE(Positive, FALSE);
                            ItemLedgEntry.SETRANGE(Open);
                            ItemLedgEntry.SETRANGE("Posting Date", ForecastEntry."Forecast Date", NextForecast."Forecast Date" - 1);
                            Item.COPYFILTER("Variant Filter", ItemLedgEntry."Variant Code");
                            IF ComponentForecast THEN BEGIN
                                ItemLedgEntry.SETRANGE("Entry Type", ItemLedgEntry."Entry Type"::Consumption);
                                ItemLedgEntry.CALCSUMS(Quantity);
                                TotalForecastQty+=ItemLedgEntry.Quantity;
                            END
                            ELSE
                            BEGIN
                                ItemLedgEntry.SETRANGE("Entry Type", ItemLedgEntry."Entry Type"::Sale);
                                ItemLedgEntry.SETRANGE("Derived from Blanket Order", FALSE);
                                ItemLedgEntry.CALCSUMS(Quantity);
                                TotalForecastQty+=ItemLedgEntry.Quantity;
                                ItemLedgEntry.SETRANGE("Derived from Blanket Order");
                                // Undo shipment shall neutralize consumption from sales
                                ItemLedgEntry.SETRANGE(Positive, TRUE);
                                ItemLedgEntry.SETRANGE(Correction, TRUE);
                                ItemLedgEntry.CALCSUMS(Quantity);
                                TotalForecastQty+=ItemLedgEntry.Quantity;
                                ItemLedgEntry.SETRANGE(Correction);
                            END;
                            DemandInvtProfile.SETRANGE("Item No.", ForecastEntry."Item No.");
                            DemandInvtProfile.SETRANGE("Due Date", ForecastEntry."Forecast Date", NextForecast."Forecast Date" - 1);
                            IF ComponentForecast THEN DemandInvtProfile.SETFILTER("Source Type", '%1|%2|%3', DATABASE::"Prod. Order Component", DATABASE::"Planning Component", DATABASE::"Assembly Line")
                            ELSE
                                DemandInvtProfile.SETFILTER("Source Type", '%1|%2', DATABASE::"Sales Line", DATABASE::"Service Line");
                            IF DemandInvtProfile.FIND('-')THEN REPEAT IF NOT(DemandInvtProfile.IsSupply OR DemandInvtProfile."Derived from Blanket Order")THEN TotalForecastQty:=TotalForecastQty - DemandInvtProfile."Remaining Quantity (Base)";
                                UNTIL(DemandInvtProfile.NEXT = 0) OR (TotalForecastQty < 0);
                            IF TotalForecastQty > 0 THEN BEGIN
                                ForecastInitDemand(DemandInvtProfile, ForecastEntry, Item."No.", ReplenishmentLocation, TotalForecastQty);
                                //Omar
                                CustomCalendarChange[1].SetSource(CustomizedCalendarChange."Source Type"::Location, DemandInvtProfile."Location Code", '', '');
                                CustomCalendarChange[2].SetSource(CustomizedCalendarChange."Source Type"::Location, DemandInvtProfile."Location Code", '', 'false');
                                //Omar
                                DemandInvtProfile."Due Date":=CalendarManagement.CalcDateBOC2('<0D>', ForecastEntry."Forecast Date", CustomCalendarChange, false);
                                IF DemandInvtProfile."Due Date" < UpdatedOrderDate THEN UpdatedOrderDate:=DemandInvtProfile."Due Date";
                                DemandInvtProfile.INSERT;
                            END;
                            ForecastEntry.SETRANGE("Forecast Date", ExcludeForecastBefore, ToDate);
                        UNTIL ForecastEntry.NEXT = 0;
                UNTIL ForecastEntry2.NEXT = 0;
        END;
    end;
    local procedure BlanketOrderConsump(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; ToDate: Date)
    var
        BlanketSalesLine: Record "Sales Line";
        QtyReleased: Decimal;
    begin
        InventoryProfile.RESET;
        BlanketSalesLine.SETCURRENTKEY(BlanketSalesLine."Document Type", BlanketSalesLine."Document No.", BlanketSalesLine.Type, BlanketSalesLine."No.");
        BlanketSalesLine.SETRANGE(BlanketSalesLine."Document Type", BlanketSalesLine."Document Type"::"Blanket Order");
        BlanketSalesLine.SETRANGE(BlanketSalesLine.Type, BlanketSalesLine.Type::Item);
        BlanketSalesLine.SETRANGE(BlanketSalesLine."No.", Item."No.");
        Item.COPYFILTER("Location Filter", BlanketSalesLine."Location Code");
        //Omar+
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN BlanketSalesLine.SETFILTER(BlanketSalesLine."Location Code", ReqWorksheetLocFilter);
        //Omar-
        Item.COPYFILTER("Variant Filter", BlanketSalesLine."Variant Code");
        BlanketSalesLine.SETFILTER(BlanketSalesLine."Outstanding Qty. (Base)", '<>0');
        BlanketSalesLine.SETFILTER(BlanketSalesLine."Shipment Date", '>%1&<=%2', 0D, ToDate);
        OnBeforeBlanketOrderConsumpFind(BlanketSalesLine);
        IF BlanketSalesLine.FIND('-')THEN REPEAT QtyReleased+=CalcInventoryProfileRemainingQty(InventoryProfile, BlanketSalesLine."Document No.");
                BlanketSalesLine.SETRANGE(BlanketSalesLine."Document No.", BlanketSalesLine."Document No.");
                BlanketSalesOrderLinesToProfile(InventoryProfile, BlanketSalesLine, QtyReleased);
                BlanketSalesLine.SETRANGE(BlanketSalesLine."Document No.");
            UNTIL BlanketSalesLine.NEXT = 0;
    end;
    local procedure BlanketSalesOrderLinesToProfile(var InventoryProfile: Record "Inventory Profile"; var BlanketSalesLine: Record "Sales Line"; var QtyReleased: Decimal)
    var
        IsSalesOrderLineCreated: Boolean;
    begin
        FOR IsSalesOrderLineCreated:=TRUE DOWNTO FALSE DO BEGIN
            BlanketSalesLine.FIND('-');
            REPEAT IF BlanketSalesLine."Quantity (Base)" <> BlanketSalesLine."Qty. to Asm. to Order (Base)" THEN IF DoProcessBlanketLine(BlanketSalesLine."Document No.", BlanketSalesLine."Line No.", IsSalesOrderLineCreated)THEN IF BlanketSalesLine."Outstanding Qty. (Base)" - BlanketSalesLine."Qty. to Asm. to Order (Base)" > QtyReleased THEN BEGIN
                            InventoryProfile.INIT;
                            InventoryProfile."Line No.":=NextLineNo;
                            InventoryProfile.TransferFromSalesLine(BlanketSalesLine, TempItemTrkgEntry);
                            InventoryProfile."Untracked Quantity":=BlanketSalesLine."Outstanding Qty. (Base)" - QtyReleased;
                            InventoryProfile."Remaining Quantity (Base)":=InventoryProfile."Untracked Quantity";
                            QtyReleased:=0;
                            InventoryProfile.INSERT;
                        END
                        ELSE
                            QtyReleased-=BlanketSalesLine."Outstanding Qty. (Base)";
            UNTIL BlanketSalesLine.NEXT = 0;
        END;
    end;
    local procedure DoProcessBlanketLine(BlanketOrderNo: Code[20]; BlanketOrderLineNo: Integer; IsSalesOrderLineCreated: Boolean): Boolean var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SETRANGE("Blanket Order No.", BlanketOrderNo);
        SalesLine.SETRANGE("Blanket Order Line No.", BlanketOrderLineNo);
        EXIT(NOT SalesLine.ISEMPTY = IsSalesOrderLineCreated)end;
    local procedure CheckForecastExist(var ForecastEntry: Record "Production Forecast Entry"; OrderDate: Date; ToDate: Date): Boolean var
        ForecastExist: Boolean;
    begin
        ForecastEntry.SETRANGE("Forecast Date", ExcludeForecastBefore, OrderDate);
        IF ForecastEntry.FIND('+')THEN REPEAT ForecastEntry.SETRANGE("Forecast Date", ForecastEntry."Forecast Date");
                ForecastEntry.CALCSUMS("Forecast Quantity (Base)");
                IF ForecastEntry."Forecast Quantity (Base)" <> 0 THEN ForecastExist:=TRUE
                ELSE
                    ForecastEntry.SETRANGE("Forecast Date", ExcludeForecastBefore, ForecastEntry."Forecast Date" - 1);
            UNTIL(NOT ForecastEntry.FIND('+')) OR ForecastExist;
        IF NOT ForecastExist THEN BEGIN
            IF ExcludeForecastBefore > OrderDate THEN ForecastEntry.SETRANGE("Forecast Date", ExcludeForecastBefore, ToDate)
            ELSE
                ForecastEntry.SETRANGE("Forecast Date", OrderDate + 1, ToDate);
            IF ForecastEntry.FIND('-')THEN REPEAT ForecastEntry.SETRANGE("Forecast Date", ForecastEntry."Forecast Date");
                    ForecastEntry.CALCSUMS("Forecast Quantity (Base)");
                    IF ForecastEntry."Forecast Quantity (Base)" <> 0 THEN ForecastExist:=TRUE
                    ELSE
                        ForecastEntry.SETRANGE("Forecast Date", ForecastEntry."Forecast Date" + 1, ToDate);
                UNTIL(NOT ForecastEntry.FIND('-')) OR ForecastExist END;
        EXIT(ForecastExist);
    end;
    local procedure FindReplishmentLocation(var ReplenishmentLocation: Code[10]; var Item: Record "Item"): Boolean var
        SKU: Record "Stockkeeping Unit";
    begin
        ReplenishmentLocation:='';
        SKU.SETCURRENTKEY("Item No.", "Location Code", "Variant Code");
        SKU.SETRANGE("Item No.", Item."No.");
        Item.COPYFILTER("Location Filter", SKU."Location Code");
        //Omar+
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN SKU.SETFILTER("Location Code", ReqWorksheetLocFilter);
        //Omar-
        Item.COPYFILTER("Variant Filter", SKU."Variant Code");
        SKU.SETRANGE("Replenishment System", Item."Replenishment System"::Purchase, Item."Replenishment System"::"Prod. Order");
        SKU.SETFILTER("Reordering Policy", '<>%1', SKU."Reordering Policy"::" ");
        IF SKU.FIND('-')THEN IF SKU.NEXT = 0 THEN ReplenishmentLocation:=SKU."Location Code";
        EXIT(ReplenishmentLocation <> '');
    end;
    local procedure FindCombination(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; var Item: Record "Item")
    var
        SKU: Record "Stockkeeping Unit";
        Location: Record "Location";
        PlanningGetParameters: Codeunit "Planning-Get Parameters";
        WMSManagement: Codeunit "WMS Management";
        VersionManagement: Codeunit "VersionManagement";
        State: Option DemandExist, SupplyExist, BothExist;
        DemandBool: Boolean;
        SupplyBool: Boolean;
        TransitLocation: Boolean;
    begin
        CreateTempSKUForComponentsLocation(Item);
        SKU.SETCURRENTKEY("Item No.", "Location Code", "Variant Code");
        SKU.SETRANGE("Item No.", Item."No.");
        Item.COPYFILTER("Variant Filter", SKU."Variant Code");
        Item.COPYFILTER("Location Filter", SKU."Location Code");
        //Omar+
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN SKU.SETFILTER("Location Code", ReqWorksheetLocFilter);
        //Omar-
        IF SKU.FINDSET THEN BEGIN
            REPEAT PlanningGetParameters.AdjustInvalidSettings(SKU);
                IF(SKU."Safety Stock Quantity" <> 0) OR (SKU."Reorder Point" <> 0) OR (SKU."Reorder Quantity" <> 0) OR (SKU."Maximum Inventory" <> 0)THEN BEGIN
                    TempSKU.TRANSFERFIELDS(SKU);
                    IF TempSKU.INSERT THEN;
                    WHILE(TempSKU."Replenishment System" = TempSKU."Replenishment System"::Transfer) AND (TempSKU."Reordering Policy" <> TempSKU."Reordering Policy"::" ")DO BEGIN
                        TempSKU."Location Code":=TempSKU."Transfer-from Code";
                        TransferPlanningParameters(TempSKU);
                        IF TempSKU."Reordering Policy" <> TempSKU."Reordering Policy"::" " THEN InsertTempSKU;
                    END;
                END;
            UNTIL SKU.NEXT = 0;
        END
        ELSE IF(NOT InvtSetup."Location Mandatory") AND (ManufacturingSetup."Components at Location" = '')THEN CreateTempSKUForLocation(Item."No.", WMSManagement.GetLastOperationLocationCode(Item."Routing No.", VersionManagement.GetRtngVersion(Item."Routing No.", SupplyInvtProfile."Due Date", TRUE)));
        CLEAR(DemandInvtProfile);
        CLEAR(SupplyInvtProfile);
        DemandInvtProfile.SETCURRENTKEY("Item No.", "Variant Code", "Location Code", "Due Date", "Attribute Priority", "Order Priority");
        SupplyInvtProfile.SETCURRENTKEY("Item No.", "Variant Code", "Location Code", "Due Date", "Attribute Priority", "Order Priority");
        DemandInvtProfile.SETRANGE(IsSupply, FALSE);
        SupplyInvtProfile.SETRANGE(IsSupply, TRUE);
        DemandBool:=DemandInvtProfile.FIND('-');
        SupplyBool:=SupplyInvtProfile.FIND('-');
        WHILE DemandBool OR SupplyBool DO BEGIN
            IF DemandBool THEN BEGIN
                TempSKU."Item No.":=DemandInvtProfile."Item No.";
                TempSKU."Variant Code":=DemandInvtProfile."Variant Code";
                TempSKU."Location Code":=DemandInvtProfile."Location Code";
                OnFindCombinationAfterAssignTempSKU(TempSKU, DemandInvtProfile);
            END
            ELSE
            BEGIN
                TempSKU."Item No.":=SupplyInvtProfile."Item No.";
                TempSKU."Variant Code":=SupplyInvtProfile."Variant Code";
                TempSKU."Location Code":=SupplyInvtProfile."Location Code";
                OnFindCombinationAfterAssignTempSKU(TempSKU, SupplyInvtProfile);
            END;
            IF DemandBool AND SupplyBool THEN State:=State::BothExist
            ELSE IF DemandBool THEN State:=State::DemandExist
                ELSE
                    State:=State::SupplyExist;
            CASE State OF State::DemandExist: DemandBool:=FindNextSKU(DemandInvtProfile);
            State::SupplyExist: SupplyBool:=FindNextSKU(SupplyInvtProfile);
            State::BothExist: IF DemandInvtProfile."Variant Code" = SupplyInvtProfile."Variant Code" THEN BEGIN
                    IF DemandInvtProfile."Location Code" = SupplyInvtProfile."Location Code" THEN BEGIN
                        DemandBool:=FindNextSKU(DemandInvtProfile);
                        SupplyBool:=FindNextSKU(SupplyInvtProfile);
                    END
                    ELSE IF DemandInvtProfile."Location Code" < SupplyInvtProfile."Location Code" THEN DemandBool:=FindNextSKU(DemandInvtProfile)
                        ELSE
                            SupplyBool:=FindNextSKU(SupplyInvtProfile)END
                ELSE IF DemandInvtProfile."Variant Code" < SupplyInvtProfile."Variant Code" THEN DemandBool:=FindNextSKU(DemandInvtProfile)
                    ELSE
                        SupplyBool:=FindNextSKU(SupplyInvtProfile);
            END;
            IF TempSKU."Location Code" <> '' THEN BEGIN
                Location.GET(TempSKU."Location Code"); // Assert: will fail if location cannot be found.
                TransitLocation:=Location."Use As In-Transit";
            END
            ELSE
                TransitLocation:=FALSE; // Variant SKU only - no location code involved.
            IF NOT TransitLocation THEN BEGIN
                TransferPlanningParameters(TempSKU);
                InsertTempSKU;
                WHILE(TempSKU."Replenishment System" = TempSKU."Replenishment System"::Transfer) AND (TempSKU."Reordering Policy" <> TempSKU."Reordering Policy"::" ")DO BEGIN
                    TempSKU."Location Code":=TempSKU."Transfer-from Code";
                    TransferPlanningParameters(TempSKU);
                    IF TempSKU."Reordering Policy" <> TempSKU."Reordering Policy"::" " THEN InsertTempSKU;
                END;
            END;
        END;
        Item.COPYFILTER("Location Filter", TempSKU."Location Code");
        //Omar+
        IF ReqWorksheetAllLoc AND (ReqWorksheetLocFilter <> '')THEN TempSKU.SETFILTER("Location Code", ReqWorksheetLocFilter);
        //Omar-
        Item.COPYFILTER("Variant Filter", TempSKU."Variant Code");
    end;
    local procedure InsertTempSKU()
    var
        SKU2: Record "Stockkeeping Unit";
        PlanningGetParameters: Codeunit "Planning-Get Parameters";
    begin
        IF NOT TempSKU.FIND('=')THEN BEGIN
            PlanningGetParameters.SetLotForLot;
            PlanningGetParameters.AtSKU(SKU2, TempSKU."Item No.", TempSKU."Variant Code", TempSKU."Location Code");
            TempSKU:=SKU2;
            IF TempSKU."Reordering Policy" <> TempSKU."Reordering Policy"::" " THEN TempSKU.INSERT;
        END;
    end;
    local procedure FindNextSKU(var InventoryProfile: Record "Inventory Profile"): Boolean begin
        TempSKU."Variant Code":=InventoryProfile."Variant Code";
        TempSKU."Location Code":=InventoryProfile."Location Code";
        InventoryProfile.SETRANGE("Variant Code", TempSKU."Variant Code");
        InventoryProfile.SETRANGE("Location Code", TempSKU."Location Code");
        InventoryProfile.FINDLAST;
        InventoryProfile.SETRANGE("Variant Code");
        InventoryProfile.SETRANGE("Location Code");
        EXIT(InventoryProfile.NEXT <> 0);
    end;
    local procedure TransferPlanningParameters(var SKU: Record "Stockkeeping Unit")
    var
        SKU2: Record "Stockkeeping Unit";
        PlanningGetParameters: Codeunit "Planning-Get Parameters";
    begin
        PlanningGetParameters.AtSKU(SKU2, SKU."Item No.", SKU."Variant Code", SKU."Location Code");
        SKU:=SKU2;
    end;
    local procedure DeleteTracking(var SKU: Record "Stockkeeping Unit"; ToDate: Date; var SupplyInventoryProfile: Record "Inventory Profile")
    var
        Item: Record "Item";
        ReservEntry1: Record "Reservation Entry";
        ResEntryWasDeleted: Boolean;
    begin
        ActionMsgEntry.SETCURRENTKEY("Reservation Entry");
        ReservEntry.RESET;
        ReservEntry.SETCURRENTKEY(ReservEntry."Item No.", ReservEntry."Variant Code", ReservEntry."Location Code");
        ReservEntry.SETRANGE(ReservEntry."Item No.", SKU."Item No.");
        ReservEntry.SETRANGE(ReservEntry."Variant Code", SKU."Variant Code");
        ReservEntry.SETRANGE(ReservEntry."Location Code", SKU."Location Code");
        ReservEntry.SETFILTER(ReservEntry."Reservation Status", '<>%1', ReservEntry."Reservation Status"::Prospect);
        IF ReservEntry.FIND('-')THEN REPEAT Item.GET(ReservEntry."Item No.");
                IF NOT IsTrkgForSpecialOrderOrDropShpt(ReservEntry)THEN BEGIN
                    IF ShouldDeleteReservEntry(ReservEntry, ToDate)THEN BEGIN
                        ResEntryWasDeleted:=TRUE;
                        IF(ReservEntry."Source Type" = DATABASE::"Item Ledger Entry") AND (ReservEntry."Reservation Status" = ReservEntry."Reservation Status"::Tracking)THEN IF ReservEntry1.GET(ReservEntry."Entry No.", NOT ReservEntry.Positive)THEN ReservEntry1.DELETE;
                        ReservEntry.DELETE;
                    END
                    ELSE
                        ResEntryWasDeleted:=CloseTracking(ReservEntry, SupplyInventoryProfile, ToDate);
                    IF ResEntryWasDeleted THEN BEGIN
                        ActionMsgEntry.SETRANGE("Reservation Entry", ReservEntry."Entry No.");
                        ActionMsgEntry.DELETEALL;
                    END;
                END;
            UNTIL ReservEntry.NEXT = 0;
    end;
    local procedure ShouldDeleteReservEntry(ReservEntry: Record "Reservation Entry"; ToDate: Date): Boolean var
        Item: Record "Item";
        IsReservedForProdComponent: Boolean;
        DeleteCondition: Boolean;
    begin
        IsReservedForProdComponent:=ReservedForProdComponent(ReservEntry);
        IF IsReservedForProdComponent AND IsProdOrderPlanned(ReservEntry) AND (ReservEntry."Reservation Status".AsInteger() > ReservEntry."Reservation Status"::Tracking.AsInteger())THEN EXIT(FALSE);
        Item.GET(ReservEntry."Item No.");
        DeleteCondition:=((ReservEntry."Reservation Status" <> ReservEntry."Reservation Status"::Reservation) AND (ReservEntry."Expected Receipt Date" <= ToDate) AND (ReservEntry."Shipment Date" <= ToDate)) OR ((ReservEntry.Binding = ReservEntry.Binding::"Order-to-Order") AND (ReservEntry."Shipment Date" <= ToDate) AND (Item."Manufacturing Policy" = Item."Manufacturing Policy"::"Make-to-Stock") AND (Item."Replenishment System" = Item."Replenishment System"::"Prod. Order") AND (NOT IsReservedForProdComponent));
        OnAfterShouldDeleteReservEntry(ReservEntry, ToDate, DeleteCondition);
        EXIT(DeleteCondition);
    end;
    local procedure IsProdOrderPlanned(ReservationEntry: Record "Reservation Entry"): Boolean var
        ProdOrderComp: Record "Prod. Order Component";
        RequisitionLine: Record "Requisition Line";
    begin
        IF NOT ProdOrderComp.GET(ReservationEntry."Source Subtype", ReservationEntry."Source ID", ReservationEntry."Source Prod. Order Line", ReservationEntry."Source Ref. No.")THEN EXIT;
        RequisitionLine.SetRefFilter(RequisitionLine."Ref. Order Type"::"Prod. Order", ProdOrderComp.Status.AsInteger(), ProdOrderComp."Prod. Order No.", ProdOrderComp."Prod. Order Line No.");
        RequisitionLine.SETRANGE("Operation No.", '');
        EXIT(NOT RequisitionLine.ISEMPTY);
    end;
    local procedure RemoveOrdinaryInventory(var Supply: Record "Inventory Profile")
    var
        Supply2: Record "Inventory Profile";
    begin
        Supply2.COPY(Supply);
        Supply.SETRANGE(Supply.IsSupply);
        Supply.SETRANGE(Supply."Source Type", DATABASE::"Item Ledger Entry");
        Supply.SETFILTER(Supply.Binding, '<>%1', Supply2.Binding::"Order-to-Order");
        Supply.DELETEALL;
        Supply.COPY(Supply2);
    end;
    local procedure UnfoldItemTracking(var ParentInvProfile: Record "Inventory Profile"; var ChildInvProfile: Record "Inventory Profile")
    begin
        ParentInvProfile.RESET;
        TempItemTrkgEntry.RESET;
        IF NOT TempItemTrkgEntry.FIND('-')THEN EXIT;
        ParentInvProfile.SETFILTER("Source Type", '<>%1', DATABASE::"Item Ledger Entry");
        ParentInvProfile.SETRANGE("Tracking Reference", 0);
        IF ParentInvProfile.FIND('-')THEN REPEAT TempItemTrkgEntry.RESET;
                TempItemTrkgEntry.SetSourceFilter(ParentInvProfile."Source Type", ParentInvProfile."Source Order Status", ParentInvProfile."Source ID", ParentInvProfile."Source Ref. No.", FALSE);
                TempItemTrkgEntry.SetSourceFilter(ParentInvProfile."Source Batch Name", ParentInvProfile."Source Prod. Order Line");
                IF TempItemTrkgEntry.FIND('-')THEN BEGIN
                    IF ParentInvProfile.IsSupply AND (ParentInvProfile.Binding <> ParentInvProfile.Binding::"Order-to-Order")THEN ParentInvProfile."Planning Flexibility":=ParentInvProfile."Planning Flexibility"::None;
                    REPEAT ChildInvProfile:=ParentInvProfile;
                        ChildInvProfile."Line No.":=NextLineNo;
                        ChildInvProfile."Tracking Reference":=ParentInvProfile."Line No.";
                        ChildInvProfile."Lot No.":=TempItemTrkgEntry."Lot No.";
                        ChildInvProfile."Serial No.":=TempItemTrkgEntry."Serial No.";
                        ChildInvProfile."Expiration Date":=TempItemTrkgEntry."Expiration Date";
                        ChildInvProfile.TransferQtyFromItemTrgkEntry(TempItemTrkgEntry);
                        OnAfterTransToChildInvProfile(TempItemTrkgEntry, ChildInvProfile);
                        ChildInvProfile.INSERT;
                        ParentInvProfile.ReduceQtyByItemTracking(ChildInvProfile);
                        ParentInvProfile.MODIFY;
                    UNTIL TempItemTrkgEntry.NEXT = 0;
                END;
            UNTIL ParentInvProfile.NEXT = 0;
    end;
    local procedure MatchAttributes(var SupplyInvtProfile: Record "Inventory Profile"; var DemandInvtProfile: Record "Inventory Profile"; RespectPlanningParm: Boolean)
    var
        xDemandInvtProfile: Record "Inventory Profile";
        xSupplyInvtProfile: Record "Inventory Profile";
        NewSupplyDate: Date;
        SupplyExists: Boolean;
        CanBeRescheduled: Boolean;
        ItemInventoryExists: Boolean;
    begin
        xDemandInvtProfile.COPYFILTERS(DemandInvtProfile);
        xSupplyInvtProfile.COPYFILTERS(SupplyInvtProfile);
        ItemInventoryExists:=CheckItemInventoryExists(SupplyInvtProfile);
        DemandInvtProfile.SETRANGE("Attribute Priority", 1, 7);
        DemandInvtProfile.SETFILTER("Source Type", '<>%1', DATABASE::"Requisition Line");
        IF DemandInvtProfile.FINDSET(TRUE)THEN REPEAT SupplyInvtProfile.SETRANGE(Binding, DemandInvtProfile.Binding);
                SupplyInvtProfile.SETRANGE("Primary Order Status", DemandInvtProfile."Primary Order Status");
                SupplyInvtProfile.SETRANGE("Primary Order No.", DemandInvtProfile."Primary Order No.");
                SupplyInvtProfile.SETRANGE("Primary Order Line", DemandInvtProfile."Primary Order Line");
                IF(DemandInvtProfile."Ref. Order Type" = DemandInvtProfile."Ref. Order Type"::Assembly) AND (DemandInvtProfile.Binding = DemandInvtProfile.Binding::"Order-to-Order") AND (DemandInvtProfile."Primary Order No." = '')THEN SupplyInvtProfile.SETRANGE("Source Prod. Order Line", DemandInvtProfile."Source Prod. Order Line");
                SupplyInvtProfile.SetTrackingFilter(DemandInvtProfile);
                SupplyExists:=SupplyInvtProfile.FINDFIRST;
                OnBeforeMatchAttributesDemandApplicationLoop(SupplyInvtProfile, DemandInvtProfile, SupplyExists);
                WHILE(DemandInvtProfile."Untracked Quantity" > 0) AND (NOT ApplyUntrackedQuantityToItemInventory(SupplyExists, ItemInventoryExists))DO BEGIN
                    OnStartOfMatchAttributesDemandApplicationLoop(SupplyInvtProfile, DemandInvtProfile, SupplyExists);
                    IF SupplyExists AND (DemandInvtProfile.Binding = DemandInvtProfile.Binding::"Order-to-Order")THEN BEGIN
                        NewSupplyDate:=SupplyInvtProfile."Due Date";
                        CanBeRescheduled:=(SupplyInvtProfile."Fixed Date" = 0D) AND ((SupplyInvtProfile."Due Date" <> DemandInvtProfile."Due Date") OR (SupplyInvtProfile."Due Time" <> DemandInvtProfile."Due Time"));
                        IF CanBeRescheduled THEN IF(SupplyInvtProfile."Due Date" > DemandInvtProfile."Due Date") OR (SupplyInvtProfile."Due Time" > DemandInvtProfile."Due Time")THEN CanBeRescheduled:=CheckScheduleIn(SupplyInvtProfile, DemandInvtProfile."Due Date", NewSupplyDate, FALSE)
                            ELSE
                                CanBeRescheduled:=CheckScheduleOut(SupplyInvtProfile, DemandInvtProfile."Due Date", NewSupplyDate, FALSE);
                        IF CanBeRescheduled AND ((NewSupplyDate <> SupplyInvtProfile."Due Date") OR (SupplyInvtProfile."Planning Level Code" > 0))THEN BEGIN
                            Reschedule(SupplyInvtProfile, DemandInvtProfile."Due Date", DemandInvtProfile."Due Time");
                            SupplyInvtProfile."Fixed Date":=SupplyInvtProfile."Due Date";
                        END;
                    END;
                    IF NOT SupplyExists OR (SupplyInvtProfile."Due Date" > DemandInvtProfile."Due Date")THEN BEGIN
                        InitSupply(SupplyInvtProfile, DemandInvtProfile."Untracked Quantity", DemandInvtProfile."Due Date");
                        TransferAttributes(SupplyInvtProfile, DemandInvtProfile);
                        SupplyInvtProfile."Fixed Date":=SupplyInvtProfile."Due Date";
                        SupplyInvtProfile.INSERT;
                        SupplyExists:=TRUE;
                    END;
                    IF DemandInvtProfile.Binding = DemandInvtProfile.Binding::"Order-to-Order" THEN IF(DemandInvtProfile."Untracked Quantity" > SupplyInvtProfile."Untracked Quantity") AND (SupplyInvtProfile."Due Date" <= DemandInvtProfile."Due Date")THEN IncreaseQtyToMeetDemand(SupplyInvtProfile, DemandInvtProfile, FALSE, RespectPlanningParm, FALSE);
                    IF SupplyInvtProfile."Untracked Quantity" < DemandInvtProfile."Untracked Quantity" THEN SupplyExists:=CloseSupply(DemandInvtProfile, SupplyInvtProfile)
                    ELSE
                        CloseDemand(DemandInvtProfile, SupplyInvtProfile);
                    OnEndMatchAttributesDemandApplicationLoop(SupplyInvtProfile, DemandInvtProfile, SupplyExists);
                END;
            UNTIL DemandInvtProfile.NEXT = 0;
        // Neutralize or generalize excess Order-To-Order Supply
        SupplyInvtProfile.COPYFILTERS(xSupplyInvtProfile);
        SupplyInvtProfile.SETRANGE(Binding, SupplyInvtProfile.Binding::"Order-to-Order");
        SupplyInvtProfile.SETFILTER("Untracked Quantity", '>=0');
        IF SupplyInvtProfile.FINDSET THEN REPEAT IF SupplyInvtProfile."Untracked Quantity" > 0 THEN BEGIN
                    IF DecreaseQty(SupplyInvtProfile, SupplyInvtProfile."Untracked Quantity", FALSE)THEN BEGIN
                        // Assertion: New specific Supply shall match the Demand exactly and must not update
                        // the Planning Line again since that will double the derived demand in case of transfers
                        IF SupplyInvtProfile."Action Message" = SupplyInvtProfile."Action Message"::New THEN SupplyInvtProfile.FIELDERROR("Action Message");
                        MaintainPlanningLine(SupplyInvtProfile, DemandInvtProfile, PlanningLineStage::Exploded, ScheduleDirection::Backward)END
                    ELSE
                    BEGIN
                        // Evaluate excess supply
                        IF TempSKU."Include Inventory" THEN BEGIN
                            // Release the remaining Untracked Quantity
                            SupplyInvtProfile.Binding:=SupplyInvtProfile.Binding::" ";
                            SupplyInvtProfile."Primary Order Type":=0;
                            SupplyInvtProfile."Primary Order Status":=0;
                            SupplyInvtProfile."Primary Order No.":='';
                            SupplyInvtProfile."Primary Order Line":=0;
                            SetAttributePriority(SupplyInvtProfile);
                        END
                        ELSE
                            SupplyInvtProfile."Untracked Quantity":=0;
                    END;
                    // Ensure that the directly allocated quantity will not be part of Projected Inventory
                    IF SupplyInvtProfile."Untracked Quantity" <> 0 THEN BEGIN
                        UpdateQty(SupplyInvtProfile, SupplyInvtProfile."Untracked Quantity");
                        SupplyInvtProfile.MODIFY;
                    END;
                END;
                IF SupplyInvtProfile."Untracked Quantity" = 0 THEN SupplyInvtProfile.DELETE;
            UNTIL SupplyInvtProfile.NEXT = 0;
        DemandInvtProfile.COPYFILTERS(xDemandInvtProfile);
        SupplyInvtProfile.COPYFILTERS(xSupplyInvtProfile);
    end;
    local procedure MatchReservationEntries(var FromTrkgReservEntry: Record "Reservation Entry"; var ToTrkgReservEntry: Record "Reservation Entry")
    begin
        IF(FromTrkgReservEntry."Reservation Status" = FromTrkgReservEntry."Reservation Status"::Reservation) XOR (ToTrkgReservEntry."Reservation Status" = ToTrkgReservEntry."Reservation Status"::Reservation)THEN BEGIN
            SwitchTrackingToReservationStatus(FromTrkgReservEntry);
            SwitchTrackingToReservationStatus(ToTrkgReservEntry);
        END;
    end;
    local procedure SwitchTrackingToReservationStatus(var ReservEntry: Record "Reservation Entry")
    begin
        IF ReservEntry."Reservation Status" = ReservEntry."Reservation Status"::Tracking THEN ReservEntry."Reservation Status":=ReservEntry."Reservation Status"::Reservation;
    end;
    local procedure PlanItem(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; PlanningStartDate: Date; ToDate: Date; RespectPlanningParm: Boolean)
    var
        TempReminderInvtProfile: Record "Inventory Profile" temporary;
        PlanningGetParameters: Codeunit "Planning-Get Parameters";
        LatestBucketStartDate: Date;
        LastProjectedInventory: Decimal;
        LastAvailableInventory: Decimal;
        SupplyWithinLeadtime: Decimal;
        DemandExists: Boolean;
        SupplyExists: Boolean;
        PlanThisSKU: Boolean;
        ROPHasBeenCrossed: Boolean;
        NewSupplyHasTakenOver: Boolean;
        WeAreSureThatDatesMatch: Boolean;
        IsReorderPointPlanning: Boolean;
        SupplyAvailableWithinLeadTime: Decimal;
        NeedOfPublishSurplus: Boolean;
        InitialProjectedInventory: Decimal;
        IsHandled: Boolean;
    begin
        ReqLine.RESET;
        ReqLine.SETRANGE("Worksheet Template Name", CurrTemplateName);
        ReqLine.SETRANGE("Journal Batch Name", CurrWorksheetName);
        ReqLine.LOCKTABLE;
        IF ReqLine.FINDLAST THEN;
        IF PlanningResilicency THEN ReqLine.SetResiliencyOn(CurrTemplateName, CurrWorksheetName, TempSKU."Item No.");
        PlanItemSetInvtProfileFilters(DemandInvtProfile, SupplyInvtProfile);
        TempReminderInvtProfile.SETCURRENTKEY("Item No.", "Variant Code", "Location Code", "Due Date");
        ExceedROPqty:=0.000000001;
        UpdateTempSKUTransferLevels;
        TempSKU.SETCURRENTKEY("Item No.", "Transfer-Level Code");
        IF TempSKU.FIND('-')THEN REPEAT IsReorderPointPlanning:=(TempSKU."Reorder Point" > TempSKU."Safety Stock Quantity") OR (TempSKU."Reordering Policy" = TempSKU."Reordering Policy"::"Maximum Qty.") OR (TempSKU."Reordering Policy" = TempSKU."Reordering Policy"::"Fixed Reorder Qty.");
                BucketSize:=TempSKU."Time Bucket";
                // Minimum bucket size is 1 day:
                IF CALCDATE(BucketSize) <= TODAY THEN EVALUATE(BucketSize, '<1D>');
                BucketSizeInDays:=CALCDATE(BucketSize) - TODAY;
                FilterDemandSupplyRelatedToSKU(DemandInvtProfile);
                FilterDemandSupplyRelatedToSKU(SupplyInvtProfile);
                DampenersDays:=PlanningGetParameters.CalcDampenerDays(TempSKU);
                DampenerQty:=PlanningGetParameters.CalcDampenerQty(TempSKU);
                OverflowLevel:=PlanningGetParameters.CalcOverflowLevel(TempSKU);
                IF NOT TempSKU."Include Inventory" THEN RemoveOrdinaryInventory(SupplyInvtProfile);
                InsertSafetyStockDemands(DemandInvtProfile, PlanningStartDate);
                UpdatePriorities(SupplyInvtProfile, IsReorderPointPlanning, ToDate);
                DemandExists:=DemandInvtProfile.FINDSET;
                SupplyExists:=SupplyInvtProfile.FINDSET;
                LatestBucketStartDate:=PlanningStartDate;
                LastProjectedInventory:=0;
                LastAvailableInventory:=0;
                PlanThisSKU:=CheckPlanSKU(TempSKU, DemandExists, SupplyExists, IsReorderPointPlanning);
                IF PlanThisSKU THEN BEGIN
                    PrepareDemand(DemandInvtProfile, IsReorderPointPlanning, ToDate);
                    PlanThisSKU:=NOT(DemandMatchedSupply(DemandInvtProfile, SupplyInvtProfile, TempSKU) AND DemandMatchedSupply(SupplyInvtProfile, DemandInvtProfile, TempSKU));
                END;
                IF PlanThisSKU THEN BEGIN
                    // Preliminary clean of tracking
                    IF DemandExists OR SupplyExists THEN DeleteTracking(TempSKU, ToDate, SupplyInvtProfile);
                    MatchAttributes(SupplyInvtProfile, DemandInvtProfile, RespectPlanningParm);
                    // Calculate initial inventory
                    PlanItemCalcInitialInventory(DemandInvtProfile, SupplyInvtProfile, PlanningStartDate, DemandExists, SupplyExists, LastProjectedInventory);
                    OnBeforePrePlanDateDemandProc(SupplyInvtProfile, DemandInvtProfile, SupplyExists, DemandExists);
                    WHILE DemandExists DO BEGIN
                        IsHandled:=FALSE;
                        OnPlanItemOnBeforeSumDemandInvtProfile(DemandInvtProfile, IsHandled);
                        IF NOT IsHandled THEN BEGIN
                            LastProjectedInventory-=DemandInvtProfile."Remaining Quantity (Base)";
                            LastAvailableInventory-=DemandInvtProfile."Untracked Quantity";
                        END;
                        DemandInvtProfile."Untracked Quantity":=0;
                        DemandInvtProfile.MODIFY;
                        DemandExists:=DemandInvtProfile.NEXT <> 0;
                    END;
                    OnBeforePrePlanDateSupplyProc(SupplyInvtProfile, DemandInvtProfile, SupplyExists, DemandExists);
                    WHILE SupplyExists DO BEGIN
                        IsHandled:=FALSE;
                        OnPlanItemOnBeforeSumSupplyInvtProfile(SupplyInvtProfile, IsHandled);
                        IF NOT IsHandled THEN BEGIN
                            LastProjectedInventory+=SupplyInvtProfile."Remaining Quantity (Base)";
                            LastAvailableInventory+=SupplyInvtProfile."Untracked Quantity";
                        END;
                        SupplyInvtProfile."Planning Flexibility":=SupplyInvtProfile."Planning Flexibility"::None;
                        SupplyInvtProfile.MODIFY;
                        SupplyExists:=SupplyInvtProfile.NEXT <> 0;
                    END;
                    OnAfterPrePlanDateSupplyProc(SupplyInvtProfile, DemandInvtProfile, SupplyExists, DemandExists);
                    IF LastAvailableInventory < 0 THEN BEGIN // Emergency order
                        // Insert Supply
                        InitSupply(SupplyInvtProfile, -LastAvailableInventory, PlanningStartDate - 1);
                        SupplyInvtProfile."Planning Flexibility":=SupplyInvtProfile."Planning Flexibility"::None;
                        SupplyInvtProfile.INSERT;
                        MaintainPlanningLine(SupplyInvtProfile, DemandInvtProfile, PlanningLineStage::Exploded, ScheduleDirection::Backward);
                        Track(SupplyInvtProfile, DemandInvtProfile, TRUE, FALSE, SupplyInvtProfile.Binding::" ");
                        LastProjectedInventory+=SupplyInvtProfile."Remaining Quantity (Base)";
                        LastAvailableInventory+=SupplyInvtProfile."Untracked Quantity";
                        PlanningTransparency.LogSurplus(SupplyInvtProfile."Line No.", SupplyInvtProfile."Line No.", 0, '', SupplyInvtProfile."Untracked Quantity", SurplusType::EmergencyOrder);
                        SupplyInvtProfile."Untracked Quantity":=0;
                        IF SupplyInvtProfile."Planning Line No." <> ReqLine."Line No." THEN ReqLine.GET(CurrTemplateName, CurrWorksheetName, SupplyInvtProfile."Planning Line No.");
                        PlanningTransparency.PublishSurplus(SupplyInvtProfile, TempSKU, ReqLine, TempTrkgReservEntry);
                        DummyInventoryProfileTrackBuffer."Warning Level":=DummyInventoryProfileTrackBuffer."Warning Level"::Emergency;
                        PlanningTransparency.LogWarning(0, ReqLine, DummyInventoryProfileTrackBuffer."Warning Level", STRSUBSTNO(Text006, DummyInventoryProfileTrackBuffer."Warning Level", -SupplyInvtProfile."Remaining Quantity (Base)", PlanningStartDate));
                        SupplyInvtProfile.DELETE;
                    END;
                    IF LastAvailableInventory < TempSKU."Safety Stock Quantity" THEN BEGIN // Initial Safety Stock Warning
                        SupplyAvailableWithinLeadTime:=SumUpAvailableSupply(SupplyInvtProfile, PlanningStartDate, PlanningStartDate);
                        InitialProjectedInventory:=LastAvailableInventory + SupplyAvailableWithinLeadTime;
                        IF InitialProjectedInventory < TempSKU."Safety Stock Quantity" THEN CreateSupplyForInitialSafetyStockWarning(SupplyInvtProfile, InitialProjectedInventory, LastProjectedInventory, LastAvailableInventory, PlanningStartDate, RespectPlanningParm, IsReorderPointPlanning);
                    END;
                    IF IsReorderPointPlanning THEN BEGIN
                        SupplyWithinLeadtime:=SumUpProjectedSupply(SupplyInvtProfile, PlanningStartDate, PlanningStartDate + BucketSizeInDays - 1);
                        IF LastProjectedInventory + SupplyWithinLeadtime <= TempSKU."Reorder Point" THEN BEGIN
                            InitSupply(SupplyInvtProfile, 0, 0D);
                            CreateSupplyForward(SupplyInvtProfile, DemandInvtProfile, PlanningStartDate, LastProjectedInventory, NewSupplyHasTakenOver, DemandInvtProfile."Due Date");
                            NeedOfPublishSurplus:=SupplyInvtProfile."Due Date" > ToDate;
                        END;
                    END;
                    // Common balancing
                    OnBeforeCommonBalancing(TempSKU, SupplyInvtProfile, DemandInvtProfile, PlanningStartDate, ToDate);
                    DemandInvtProfile.SETRANGE("Due Date", PlanningStartDate, ToDate);
                    DemandExists:=DemandInvtProfile.FINDSET;
                    DemandInvtProfile.SETRANGE("Due Date");
                    SupplyInvtProfile.SETFILTER("Untracked Quantity", '>=0');
                    SupplyExists:=SupplyInvtProfile.FINDSET;
                    SupplyInvtProfile.SETRANGE("Untracked Quantity");
                    SupplyInvtProfile.SETRANGE("Due Date");
                    IF NOT SupplyExists THEN IF NOT SupplyInvtProfile.ISEMPTY THEN BEGIN
                            SupplyInvtProfile.SETRANGE("Due Date", PlanningStartDate, ToDate);
                            SupplyExists:=SupplyInvtProfile.FINDSET;
                            SupplyInvtProfile.SETRANGE("Due Date");
                            IF NeedOfPublishSurplus AND NOT(DemandExists OR SupplyExists)THEN BEGIN
                                Track(SupplyInvtProfile, DemandInvtProfile, TRUE, FALSE, SupplyInvtProfile.Binding::" ");
                                PlanningTransparency.PublishSurplus(SupplyInvtProfile, TempSKU, ReqLine, TempTrkgReservEntry);
                            END;
                        END;
                    IF IsReorderPointPlanning THEN ChkInitialOverflow(DemandInvtProfile, SupplyInvtProfile, OverflowLevel, LastProjectedInventory, PlanningStartDate, ToDate);
                    CheckSupplyWithSKU(SupplyInvtProfile, TempSKU);
                    LotAccumulationPeriodStartDate:=0D;
                    NextState:=NextState::StartOver;
                    WHILE PlanThisSKU DO CASE NextState OF NextState::StartOver: PlanItemNextStateStartOver(DemandInvtProfile, SupplyInvtProfile, DemandExists, SupplyExists);
                        NextState::MatchDates: PlanItemNextStateMatchDates(DemandInvtProfile, SupplyInvtProfile, TempReminderInvtProfile, WeAreSureThatDatesMatch, IsReorderPointPlanning, LastProjectedInventory, LatestBucketStartDate, ROPHasBeenCrossed, NewSupplyHasTakenOver);
                        NextState::MatchQty: PlanItemNextStateMatchQty(DemandInvtProfile, SupplyInvtProfile, LastProjectedInventory, IsReorderPointPlanning, RespectPlanningParm);
                        NextState::CreateSupply: PlanItemNextStateCreateSupply(DemandInvtProfile, SupplyInvtProfile, TempReminderInvtProfile, WeAreSureThatDatesMatch, IsReorderPointPlanning, LastProjectedInventory, LatestBucketStartDate, ROPHasBeenCrossed, NewSupplyHasTakenOver, SupplyExists, RespectPlanningParm);
                        NextState::ReduceSupply: PlanItemNextStateReduceSupply(DemandInvtProfile, SupplyInvtProfile, TempReminderInvtProfile, IsReorderPointPlanning, LastProjectedInventory, LatestBucketStartDate, ROPHasBeenCrossed, NewSupplyHasTakenOver, DemandExists);
                        NextState::CloseDemand: PlanItemNextStateCloseDemand(DemandInvtProfile, SupplyInvtProfile, TempReminderInvtProfile, IsReorderPointPlanning, LatestBucketStartDate, DemandExists, SupplyExists, PlanningStartDate);
                        NextState::CloseSupply: PlanItemNextStateCloseSupply(DemandInvtProfile, SupplyInvtProfile, TempReminderInvtProfile, IsReorderPointPlanning, LatestBucketStartDate, DemandExists, SupplyExists, ToDate);
                        NextState::CloseLoop: PlanItemNextStateCloseLoop(DemandInvtProfile, SupplyInvtProfile, TempReminderInvtProfile, IsReorderPointPlanning, LastProjectedInventory, LatestBucketStartDate, ROPHasBeenCrossed, NewSupplyHasTakenOver, SupplyExists, ToDate, PlanThisSKU);
                        ELSE
                            ERROR(Text001, SELECTSTR(NextState + 1, NextStateTxt));
                        END;
                END;
            UNTIL TempSKU.NEXT = 0;
        SetAcceptAction(TempSKU."Item No.");
    end;
    local procedure PlanItemCalcInitialInventory(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; PlanningStartDate: Date; var DemandExists: Boolean; var SupplyExists: Boolean; var LastProjectedInventory: Decimal)
    begin
        DemandInvtProfile.SETRANGE("Due Date", 0D, PlanningStartDate - 1);
        SupplyInvtProfile.SETRANGE("Due Date", 0D, PlanningStartDate - 1);
        DemandExists:=DemandInvtProfile.FINDSET;
        SupplyExists:=SupplyInvtProfile.FINDSET;
        OnBeforePrePlanDateApplicationLoop(SupplyInvtProfile, DemandInvtProfile, SupplyExists, DemandExists);
        WHILE DemandExists AND SupplyExists DO BEGIN
            OnStartOfPrePlanDateApplicationLoop(SupplyInvtProfile, DemandInvtProfile, SupplyExists, DemandExists);
            IF DemandInvtProfile."Untracked Quantity" > SupplyInvtProfile."Untracked Quantity" THEN BEGIN
                LastProjectedInventory+=SupplyInvtProfile."Remaining Quantity (Base)";
                DemandInvtProfile."Untracked Quantity"-=SupplyInvtProfile."Untracked Quantity";
                FrozenZoneTrack(SupplyInvtProfile, DemandInvtProfile);
                SupplyInvtProfile."Untracked Quantity":=0;
                SupplyInvtProfile.MODIFY;
                SupplyExists:=SupplyInvtProfile.NEXT <> 0;
            END
            ELSE
            BEGIN
                LastProjectedInventory-=DemandInvtProfile."Remaining Quantity (Base)";
                SupplyInvtProfile."Untracked Quantity"-=DemandInvtProfile."Untracked Quantity";
                FrozenZoneTrack(DemandInvtProfile, SupplyInvtProfile);
                DemandInvtProfile."Untracked Quantity":=0;
                DemandInvtProfile.MODIFY;
                DemandExists:=DemandInvtProfile.NEXT <> 0;
                IF NOT DemandExists THEN SupplyInvtProfile.MODIFY;
            END;
            OnEndOfPrePlanDateApplicationLoop(SupplyInvtProfile, DemandInvtProfile, SupplyExists, DemandExists);
        END;
    end;
    local procedure PlanItemNextStateCloseDemand(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; var TempReminderInvtProfile: Record "Inventory Profile" temporary; IsReorderPointPlanning: Boolean; LatestBucketStartDate: Date; var DemandExists: Boolean; var SupplyExists: Boolean; PlanningStartDate: Date)
    begin
        IF DemandInvtProfile."Due Date" < PlanningStartDate THEN ERROR(Text001, DemandInvtProfile.FIELDCAPTION("Due Date"));
        IF DemandInvtProfile."Order Relation" = DemandInvtProfile."Order Relation"::"Safety Stock" THEN BEGIN
            AllocateSafetystock(SupplyInvtProfile, DemandInvtProfile."Untracked Quantity", DemandInvtProfile."Due Date");
            IF IsReorderPointPlanning AND (SupplyInvtProfile."Due Date" >= LatestBucketStartDate)THEN PostInvChgReminder(TempReminderInvtProfile, SupplyInvtProfile, TRUE);
        END
        ELSE
        BEGIN
            IF IsReorderPointPlanning THEN PostInvChgReminder(TempReminderInvtProfile, DemandInvtProfile, FALSE);
            IF DemandInvtProfile."Untracked Quantity" <> 0 THEN BEGIN
                SupplyInvtProfile."Untracked Quantity"-=DemandInvtProfile."Untracked Quantity";
                IF SupplyInvtProfile."Untracked Quantity" < SupplyInvtProfile."Safety Stock Quantity" THEN SupplyInvtProfile."Safety Stock Quantity":=SupplyInvtProfile."Untracked Quantity";
                IF SupplyInvtProfile."Action Message" <> SupplyInvtProfile."Action Message"::" " THEN MaintainPlanningLine(SupplyInvtProfile, DemandInvtProfile, PlanningLineStage::"Line Created", ScheduleDirection::Backward);
                SupplyInvtProfile.MODIFY;
                IF IsReorderPointPlanning AND (SupplyInvtProfile."Due Date" >= LatestBucketStartDate)THEN PostInvChgReminder(TempReminderInvtProfile, SupplyInvtProfile, TRUE);
                CheckSupplyAndTrack(DemandInvtProfile, SupplyInvtProfile);
                SurplusType:=PlanningTransparency.FindReason(DemandInvtProfile);
                IF SurplusType <> SurplusType::None THEN PlanningTransparency.LogSurplus(SupplyInvtProfile."Line No.", DemandInvtProfile."Line No.", DemandInvtProfile."Source Type", DemandInvtProfile."Source ID", DemandInvtProfile."Untracked Quantity", SurplusType);
            END;
        END;
        DemandInvtProfile.DELETE;
        // If just handled demand was safetystock
        IF DemandInvtProfile."Order Relation" = DemandInvtProfile."Order Relation"::"Safety Stock" THEN SupplyExists:=SupplyInvtProfile.FINDSET(TRUE); // We assume that next profile is NOT safety stock
        DemandExists:=DemandInvtProfile.NEXT <> 0;
        NextState:=NextState::StartOver;
    end;
    local procedure PlanItemNextStateCloseLoop(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; var TempReminderInvtProfile: Record "Inventory Profile" temporary; IsReorderPointPlanning: Boolean; var LastProjectedInventory: Decimal; var LatestBucketStartDate: Date; var ROPHasBeenCrossed: Boolean; var NewSupplyHasTakenOver: Boolean; var SupplyExists: Boolean; ToDate: Date; var PlanThisSKU: Boolean)
    begin
        IF IsReorderPointPlanning THEN MaintainProjectedInventory(TempReminderInvtProfile, ToDate, LastProjectedInventory, LatestBucketStartDate, ROPHasBeenCrossed);
        IF ROPHasBeenCrossed THEN BEGIN
            CreateSupplyForward(SupplyInvtProfile, DemandInvtProfile, LatestBucketStartDate, LastProjectedInventory, NewSupplyHasTakenOver, DemandInvtProfile."Due Date");
            SupplyExists:=TRUE;
            NextState:=NextState::StartOver;
        END
        ELSE
            PlanThisSKU:=FALSE;
    end;
    local procedure PlanItemNextStateCloseSupply(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; var TempReminderInvtProfile: Record "Inventory Profile" temporary; IsReorderPointPlanning: Boolean; LatestBucketStartDate: Date; DemandExists: Boolean; var SupplyExists: Boolean; ToDate: Date)
    begin
        IF DemandExists AND (SupplyInvtProfile."Untracked Quantity" > 0)THEN BEGIN
            DemandInvtProfile."Untracked Quantity"-=SupplyInvtProfile."Untracked Quantity";
            DemandInvtProfile.MODIFY;
        END;
        IF DemandExists AND (DemandInvtProfile."Order Relation" = DemandInvtProfile."Order Relation"::"Safety Stock")THEN BEGIN
            AllocateSafetystock(SupplyInvtProfile, SupplyInvtProfile."Untracked Quantity", DemandInvtProfile."Due Date");
            IF IsReorderPointPlanning AND (SupplyInvtProfile."Due Date" >= LatestBucketStartDate)THEN PostInvChgReminder(TempReminderInvtProfile, SupplyInvtProfile, TRUE);
        END
        ELSE
        BEGIN
            IF IsReorderPointPlanning AND (SupplyInvtProfile."Due Date" >= LatestBucketStartDate)THEN PostInvChgReminder(TempReminderInvtProfile, SupplyInvtProfile, FALSE);
            IF SupplyInvtProfile."Action Message" <> SupplyInvtProfile."Action Message"::" " THEN MaintainPlanningLine(SupplyInvtProfile, DemandInvtProfile, PlanningLineStage::Exploded, ScheduleDirection::Backward)
            ELSE
                SupplyInvtProfile.TESTFIELD("Planning Line No.", 0);
            IF(SupplyInvtProfile."Action Message" = SupplyInvtProfile."Action Message"::New) OR (SupplyInvtProfile."Due Date" <= ToDate)THEN IF DemandExists THEN Track(SupplyInvtProfile, DemandInvtProfile, FALSE, FALSE, SupplyInvtProfile.Binding)
                ELSE
                    Track(SupplyInvtProfile, DemandInvtProfile, TRUE, FALSE, SupplyInvtProfile.Binding::" ");
            SupplyInvtProfile.DELETE;
            // Planning Transparency
            IF DemandExists THEN BEGIN
                SurplusType:=PlanningTransparency.FindReason(DemandInvtProfile);
                IF SurplusType <> SurplusType::None THEN PlanningTransparency.LogSurplus(SupplyInvtProfile."Line No.", DemandInvtProfile."Line No.", DemandInvtProfile."Source Type", DemandInvtProfile."Source ID", SupplyInvtProfile."Untracked Quantity", SurplusType);
            END;
            IF SupplyInvtProfile."Planning Line No." <> 0 THEN BEGIN
                IF SupplyInvtProfile."Safety Stock Quantity" > 0 THEN PlanningTransparency.LogSurplus(SupplyInvtProfile."Line No.", SupplyInvtProfile."Line No.", 0, '', SupplyInvtProfile."Safety Stock Quantity", SurplusType::SafetyStock);
                IF SupplyInvtProfile."Planning Line No." <> ReqLine."Line No." THEN ReqLine.GET(CurrTemplateName, CurrWorksheetName, SupplyInvtProfile."Planning Line No.");
                PlanningTransparency.PublishSurplus(SupplyInvtProfile, TempSKU, ReqLine, TempTrkgReservEntry);
            END
            ELSE
                PlanningTransparency.CleanLog(SupplyInvtProfile."Line No.");
        END;
        IF TempSKU."Maximum Order Quantity" > 0 THEN CheckSupplyRemQtyAndUntrackQty(SupplyInvtProfile);
        SupplyExists:=SupplyInvtProfile.NEXT <> 0;
        NextState:=NextState::StartOver;
    end;
    local procedure PlanItemNextStateCreateSupply(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; var TempReminderInvtProfile: Record "Inventory Profile" temporary; var WeAreSureThatDatesMatch: Boolean; IsReorderPointPlanning: Boolean; var LastProjectedInventory: Decimal; var LatestBucketStartDate: Date; var ROPHasBeenCrossed: Boolean; var NewSupplyHasTakenOver: Boolean; var SupplyExists: Boolean; RespectPlanningParm: Boolean)
    var
        NewSupplyDate: Date;
        IsExceptionOrder: Boolean;
    begin
        WeAreSureThatDatesMatch:=TRUE; // We assume this is true at this point.....
        IF FromLotAccumulationPeriodStartDate(LotAccumulationPeriodStartDate, DemandInvtProfile."Due Date")THEN NewSupplyDate:=LotAccumulationPeriodStartDate
        ELSE
        BEGIN
            NewSupplyDate:=DemandInvtProfile."Due Date";
            LotAccumulationPeriodStartDate:=0D;
        END;
        IF(NewSupplyDate >= LatestBucketStartDate) AND IsReorderPointPlanning THEN MaintainProjectedInventory(TempReminderInvtProfile, NewSupplyDate, LastProjectedInventory, LatestBucketStartDate, ROPHasBeenCrossed);
        IF ROPHasBeenCrossed THEN BEGIN
            CreateSupplyForward(SupplyInvtProfile, DemandInvtProfile, LatestBucketStartDate, LastProjectedInventory, NewSupplyHasTakenOver, DemandInvtProfile."Due Date");
            IF NewSupplyHasTakenOver THEN BEGIN
                SupplyExists:=TRUE;
                WeAreSureThatDatesMatch:=FALSE;
                NextState:=NextState::MatchDates;
            END;
        END;
        IF WeAreSureThatDatesMatch THEN BEGIN
            IsExceptionOrder:=IsReorderPointPlanning;
            CreateSupply(SupplyInvtProfile, DemandInvtProfile, LastProjectedInventory + QtyFromPendingReminders(TempReminderInvtProfile, DemandInvtProfile."Due Date", LatestBucketStartDate) - DemandInvtProfile."Remaining Quantity (Base)", IsExceptionOrder, RespectPlanningParm);
            SupplyInvtProfile."Due Date":=NewSupplyDate;
            SupplyInvtProfile."Fixed Date":=SupplyInvtProfile."Due Date"; // We note the latest possible date on the SupplyInvtProfile.
            SupplyExists:=TRUE;
            IF IsExceptionOrder THEN BEGIN
                DummyInventoryProfileTrackBuffer."Warning Level":=DummyInventoryProfileTrackBuffer."Warning Level"::Exception;
                PlanningTransparency.LogWarning(SupplyInvtProfile."Line No.", ReqLine, DummyInventoryProfileTrackBuffer."Warning Level", STRSUBSTNO(Text007, DummyInventoryProfileTrackBuffer."Warning Level", TempSKU.FIELDCAPTION("Safety Stock Quantity"), TempSKU."Safety Stock Quantity", DemandInvtProfile."Due Date"));
            END;
            NextState:=NextState::MatchQty;
        END;
    end;
    local procedure PlanItemNextStateMatchDates(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; var TempReminderInvtProfile: Record "Inventory Profile" temporary; var WeAreSureThatDatesMatch: Boolean; IsReorderPointPlanning: Boolean; var LastProjectedInventory: Decimal; var LatestBucketStartDate: Date; var ROPHasBeenCrossed: Boolean; var NewSupplyHasTakenOver: Boolean)
    var
        OriginalSupplyDate: Date;
        NewSupplyDate: Date;
    begin
        OriginalSupplyDate:=SupplyInvtProfile."Due Date";
        NewSupplyDate:=SupplyInvtProfile."Due Date";
        WeAreSureThatDatesMatch:=FALSE;
        IF DemandInvtProfile."Due Date" < SupplyInvtProfile."Due Date" THEN BEGIN
            IF CheckScheduleIn(SupplyInvtProfile, DemandInvtProfile."Due Date", NewSupplyDate, TRUE)THEN WeAreSureThatDatesMatch:=TRUE
            ELSE
                NextState:=NextState::CreateSupply;
        END
        ELSE IF DemandInvtProfile."Due Date" > SupplyInvtProfile."Due Date" THEN BEGIN
                IF CheckScheduleOut(SupplyInvtProfile, DemandInvtProfile."Due Date", NewSupplyDate, TRUE)THEN WeAreSureThatDatesMatch:=NOT ScheduleAllOutChangesSequence(SupplyInvtProfile, NewSupplyDate)
                ELSE
                    NextState:=NextState::ReduceSupply;
            END
            ELSE
                WeAreSureThatDatesMatch:=TRUE;
        IF WeAreSureThatDatesMatch AND IsReorderPointPlanning THEN BEGIN
            // Now we know the final position on the timeline of the SupplyInvtProfile.
            MaintainProjectedInventory(TempReminderInvtProfile, NewSupplyDate, LastProjectedInventory, LatestBucketStartDate, ROPHasBeenCrossed);
            IF ROPHasBeenCrossed THEN BEGIN
                CreateSupplyForward(SupplyInvtProfile, DemandInvtProfile, LatestBucketStartDate, LastProjectedInventory, NewSupplyHasTakenOver, DemandInvtProfile."Due Date");
                IF NewSupplyHasTakenOver THEN BEGIN
                    WeAreSureThatDatesMatch:=FALSE;
                    NextState:=NextState::MatchDates;
                END;
            END;
        END;
        IF WeAreSureThatDatesMatch THEN BEGIN
            IF NewSupplyDate <> OriginalSupplyDate THEN Reschedule(SupplyInvtProfile, NewSupplyDate, 0T);
            SupplyInvtProfile.TESTFIELD("Due Date", NewSupplyDate);
            SupplyInvtProfile."Fixed Date":=SupplyInvtProfile."Due Date"; // We note the latest possible date on the SupplyInvtProfile.
            NextState:=NextState::MatchQty;
        END;
    end;
    local procedure PlanItemNextStateMatchQty(var DemandInventoryProfile: Record "Inventory Profile"; var SupplyInventoryProfile: Record "Inventory Profile"; var LastProjectedInventory: Decimal; IsReorderPointPlanning: Boolean; RespectPlanningParm: Boolean)
    begin
        CASE TRUE OF SupplyInventoryProfile."Untracked Quantity" >= DemandInventoryProfile."Untracked Quantity": NextState:=NextState::CloseDemand;
        ShallSupplyBeClosed(SupplyInventoryProfile, DemandInventoryProfile."Due Date", IsReorderPointPlanning): NextState:=NextState::CloseSupply;
        IncreaseQtyToMeetDemand(SupplyInventoryProfile, DemandInventoryProfile, TRUE, RespectPlanningParm, TRUE): BEGIN
            NextState:=NextState::CloseDemand;
            // initial Safety Stock can be changed to normal, if we can increase qty for normal demand
            IF(SupplyInventoryProfile."Order Relation" = SupplyInventoryProfile."Order Relation"::"Safety Stock") AND (DemandInventoryProfile."Order Relation" = DemandInventoryProfile."Order Relation"::Normal)THEN BEGIN
                SupplyInventoryProfile."Order Relation":=SupplyInventoryProfile."Order Relation"::Normal;
                LastProjectedInventory-=TempSKU."Safety Stock Quantity";
            END;
        END;
        ELSE
        BEGIN
            NextState:=NextState::CloseSupply;
            IF TempSKU."Maximum Order Quantity" > 0 THEN LotAccumulationPeriodStartDate:=SupplyInventoryProfile."Due Date";
        END;
        END;
    end;
    local procedure PlanItemNextStateReduceSupply(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; var TempReminderInvtProfile: Record "Inventory Profile" temporary; IsReorderPointPlanning: Boolean; var LastProjectedInventory: Decimal; var LatestBucketStartDate: Date; var ROPHasBeenCrossed: Boolean; var NewSupplyHasTakenOver: Boolean; DemandExists: Boolean)
    begin
        IF IsReorderPointPlanning AND (SupplyInvtProfile."Due Date" >= LatestBucketStartDate)THEN MaintainProjectedInventory(TempReminderInvtProfile, SupplyInvtProfile."Due Date", LastProjectedInventory, LatestBucketStartDate, ROPHasBeenCrossed);
        NewSupplyHasTakenOver:=FALSE;
        IF ROPHasBeenCrossed THEN BEGIN
            CreateSupplyForward(SupplyInvtProfile, DemandInvtProfile, LatestBucketStartDate, LastProjectedInventory, NewSupplyHasTakenOver, SupplyInvtProfile."Due Date");
            IF NewSupplyHasTakenOver THEN BEGIN
                IF DemandExists THEN NextState:=NextState::MatchDates
                ELSE
                    NextState:=NextState::CloseSupply;
            END;
        END;
        IF NOT NewSupplyHasTakenOver THEN IF DecreaseQty(SupplyInvtProfile, SupplyInvtProfile."Untracked Quantity", TRUE)THEN NextState:=NextState::CloseSupply
            ELSE
            BEGIN
                SupplyInvtProfile."Max. Quantity":=SupplyInvtProfile."Remaining Quantity (Base)";
                IF DemandExists THEN NextState:=NextState::MatchQty
                ELSE
                    NextState:=NextState::CloseSupply;
            END;
    end;
    local procedure PlanItemNextStateStartOver(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; var DemandExists: Boolean; var SupplyExists: Boolean)
    var
        IsHandled: Boolean;
    begin
        IF DemandExists AND (DemandInvtProfile."Source Type" = DATABASE::"Transfer Line")THEN WHILE CancelTransfer(SupplyInvtProfile, DemandInvtProfile, DemandExists)DO DemandExists:=DemandInvtProfile.NEXT <> 0;
        IsHandled:=FALSE;
        OnBeforePlanStepSettingOnStartOver(SupplyInvtProfile, DemandInvtProfile, SupplyExists, DemandExists, NextState, IsHandled);
        IF NOT IsHandled THEN IF DemandExists THEN IF DemandInvtProfile."Untracked Quantity" = 0 THEN NextState:=NextState::CloseDemand
                ELSE IF SupplyExists THEN NextState:=NextState::MatchDates
                    ELSE
                        NextState:=NextState::CreateSupply
            ELSE IF SupplyExists THEN NextState:=NextState::ReduceSupply
                ELSE
                    NextState:=NextState::CloseLoop;
    end;
    local procedure PlanItemSetInvtProfileFilters(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile")
    begin
        DemandInvtProfile.RESET;
        SupplyInvtProfile.RESET;
        DemandInvtProfile.SETRANGE(IsSupply, FALSE);
        SupplyInvtProfile.SETRANGE(IsSupply, TRUE);
        DemandInvtProfile.SETCURRENTKEY("Item No.", "Variant Code", "Location Code", "Due Date", "Attribute Priority", "Order Priority");
        SupplyInvtProfile.SETCURRENTKEY("Item No.", "Variant Code", "Location Code", "Due Date", "Attribute Priority", "Order Priority");
        SupplyInvtProfile.SETRANGE("Drop Shipment", FALSE);
        SupplyInvtProfile.SETRANGE("Special Order", FALSE);
        DemandInvtProfile.SETRANGE("Drop Shipment", FALSE);
        DemandInvtProfile.SETRANGE("Special Order", FALSE);
    end;
    local procedure FilterDemandSupplyRelatedToSKU(var InventoryProfile: Record "Inventory Profile")
    begin
        InventoryProfile.SETRANGE("Item No.", TempSKU."Item No.");
        InventoryProfile.SETRANGE("Variant Code", TempSKU."Variant Code");
        InventoryProfile.SETRANGE("Location Code", TempSKU."Location Code");
    end;
    local procedure ScheduleForward(var SupplyInvtProfile: Record "Inventory Profile"; DemandInvtProfile: Record "Inventory Profile"; StartingDate: Date)
    begin
        SupplyInvtProfile."Starting Date":=StartingDate;
        MaintainPlanningLine(SupplyInvtProfile, DemandInvtProfile, PlanningLineStage::"Routing Created", ScheduleDirection::Forward);
        IF(SupplyInvtProfile."Fixed Date" > 0D) AND (SupplyInvtProfile."Fixed Date" < SupplyInvtProfile."Due Date")THEN SupplyInvtProfile."Due Date":=SupplyInvtProfile."Fixed Date"
        ELSE
            SupplyInvtProfile."Fixed Date":=SupplyInvtProfile."Due Date";
    end;
    local procedure IncreaseQtyToMeetDemand(var SupplyInvtProfile: Record "Inventory Profile"; DemandInvtProfile: Record "Inventory Profile"; LimitedHorizon: Boolean; RespectPlanningParm: Boolean; CheckSourceType: Boolean): Boolean var
        TotalDemandedQty: Decimal;
    begin
        IF SupplyInvtProfile."Planning Flexibility" <> SupplyInvtProfile."Planning Flexibility"::Unlimited THEN EXIT(FALSE);
        IF CheckSourceType THEN IF(DemandInvtProfile."Source Type" = DATABASE::"Planning Component") AND (SupplyInvtProfile."Source Type" = DATABASE::"Prod. Order Line") AND (DemandInvtProfile.Binding = DemandInvtProfile.Binding::"Order-to-Order")THEN EXIT(FALSE);
        IF(SupplyInvtProfile."Max. Quantity" > 0) OR (SupplyInvtProfile."Action Message" = SupplyInvtProfile."Action Message"::Cancel)THEN IF SupplyInvtProfile."Max. Quantity" <= SupplyInvtProfile."Remaining Quantity (Base)" THEN EXIT(FALSE);
        IF LimitedHorizon THEN IF NOT AllowLotAccumulation(SupplyInvtProfile, DemandInvtProfile."Due Date")THEN EXIT(FALSE);
        TotalDemandedQty:=DemandInvtProfile."Untracked Quantity";
        IncreaseQty(SupplyInvtProfile, DemandInvtProfile."Untracked Quantity" - SupplyInvtProfile."Untracked Quantity", RespectPlanningParm);
        EXIT(TotalDemandedQty <= SupplyInvtProfile."Untracked Quantity");
    end;
    local procedure IncreaseQty(var SupplyInvtProfile: Record "Inventory Profile"; NeededQty: Decimal; RespectPlanningParm: Boolean)
    var
        TempQty: Decimal;
    begin
        TempQty:=SupplyInvtProfile."Remaining Quantity (Base)";
        IF NOT SupplyInvtProfile."Is Exception Order" OR RespectPlanningParm THEN SupplyInvtProfile."Remaining Quantity (Base)"+=NeededQty + AdjustReorderQty(SupplyInvtProfile."Remaining Quantity (Base)" + NeededQty, TempSKU, SupplyInvtProfile."Line No.", SupplyInvtProfile."Min. Quantity")
        ELSE
            SupplyInvtProfile."Remaining Quantity (Base)"+=NeededQty;
        IF TempSKU."Maximum Order Quantity" > 0 THEN IF SupplyInvtProfile."Remaining Quantity (Base)" > TempSKU."Maximum Order Quantity" THEN SupplyInvtProfile."Remaining Quantity (Base)":=TempSKU."Maximum Order Quantity";
        IF(SupplyInvtProfile."Action Message" <> SupplyInvtProfile."Action Message"::New) AND (SupplyInvtProfile."Remaining Quantity (Base)" <> TempQty)THEN BEGIN
            IF SupplyInvtProfile."Original Quantity" = 0 THEN SupplyInvtProfile."Original Quantity":=SupplyInvtProfile.Quantity;
            IF SupplyInvtProfile."Original Due Date" = 0D THEN SupplyInvtProfile."Action Message":=SupplyInvtProfile."Action Message"::"Change Qty."
            ELSE
                SupplyInvtProfile."Action Message":=SupplyInvtProfile."Action Message"::"Resched. & Chg. Qty.";
        END;
        SupplyInvtProfile."Untracked Quantity":=SupplyInvtProfile."Untracked Quantity" + SupplyInvtProfile."Remaining Quantity (Base)" - TempQty;
        SupplyInvtProfile."Quantity (Base)":=SupplyInvtProfile."Quantity (Base)" + SupplyInvtProfile."Remaining Quantity (Base)" - TempQty;
        SupplyInvtProfile.MODIFY;
    end;
    local procedure DecreaseQty(var SupplyInvtProfile: Record "Inventory Profile"; ReduceQty: Decimal; RespectPlanningParm: Boolean): Boolean var
        TempQty: Decimal;
    begin
        IF NOT CanDecreaseSupply(SupplyInvtProfile, ReduceQty)THEN BEGIN
            IF(ReduceQty <= DampenerQty) AND (SupplyInvtProfile."Planning Level Code" = 0)THEN PlanningTransparency.LogSurplus(SupplyInvtProfile."Line No.", 0, DATABASE::"Manufacturing Setup", SupplyInvtProfile."Source ID", DampenerQty, SurplusType::DampenerQty);
            EXIT(FALSE);
        END;
        IF ReduceQty > 0 THEN BEGIN
            TempQty:=SupplyInvtProfile."Remaining Quantity (Base)";
            IF RespectPlanningParm THEN SupplyInvtProfile."Remaining Quantity (Base)":=SupplyInvtProfile."Remaining Quantity (Base)" - ReduceQty + AdjustReorderQty(SupplyInvtProfile."Remaining Quantity (Base)" - ReduceQty, TempSKU, SupplyInvtProfile."Line No.", SupplyInvtProfile."Min. Quantity")
            ELSE
                SupplyInvtProfile."Remaining Quantity (Base)"-=ReduceQty;
            IF TempSKU."Maximum Order Quantity" > 0 THEN IF SupplyInvtProfile."Remaining Quantity (Base)" > TempSKU."Maximum Order Quantity" THEN SupplyInvtProfile."Remaining Quantity (Base)":=TempSKU."Maximum Order Quantity";
            IF(SupplyInvtProfile."Action Message" <> SupplyInvtProfile."Action Message"::New) AND (TempQty <> SupplyInvtProfile."Remaining Quantity (Base)")THEN BEGIN
                IF SupplyInvtProfile."Original Quantity" = 0 THEN SupplyInvtProfile."Original Quantity":=SupplyInvtProfile.Quantity;
                IF SupplyInvtProfile."Remaining Quantity (Base)" = 0 THEN SupplyInvtProfile."Action Message":=SupplyInvtProfile."Action Message"::Cancel
                ELSE IF SupplyInvtProfile."Original Due Date" = 0D THEN SupplyInvtProfile."Action Message":=SupplyInvtProfile."Action Message"::"Change Qty."
                    ELSE
                        SupplyInvtProfile."Action Message":=SupplyInvtProfile."Action Message"::"Resched. & Chg. Qty.";
            END;
            SupplyInvtProfile."Untracked Quantity":=SupplyInvtProfile."Untracked Quantity" - TempQty + SupplyInvtProfile."Remaining Quantity (Base)";
            SupplyInvtProfile."Quantity (Base)":=SupplyInvtProfile."Quantity (Base)" - TempQty + SupplyInvtProfile."Remaining Quantity (Base)";
            SupplyInvtProfile.MODIFY;
        END;
        EXIT(SupplyInvtProfile."Untracked Quantity" = 0);
    end;
    local procedure CanDecreaseSupply(InventoryProfileSupply: Record "Inventory Profile"; var ReduceQty: Decimal): Boolean var
        TrackedQty: Decimal;
    begin
        IF ReduceQty > InventoryProfileSupply."Untracked Quantity" THEN ReduceQty:=InventoryProfileSupply."Untracked Quantity";
        IF InventoryProfileSupply."Min. Quantity" > InventoryProfileSupply."Remaining Quantity (Base)" - ReduceQty THEN ReduceQty:=InventoryProfileSupply."Remaining Quantity (Base)" - InventoryProfileSupply."Min. Quantity";
        // Ensure leaving enough untracked qty. to cover the safety stock
        TrackedQty:=InventoryProfileSupply."Remaining Quantity (Base)" - InventoryProfileSupply."Untracked Quantity";
        IF TrackedQty + InventoryProfileSupply."Safety Stock Quantity" > InventoryProfileSupply."Remaining Quantity (Base)" - ReduceQty THEN ReduceQty:=InventoryProfileSupply."Remaining Quantity (Base)" - (TrackedQty + InventoryProfileSupply."Safety Stock Quantity");
        // Planning Transparency
        IF(ReduceQty <= DampenerQty) AND (InventoryProfileSupply."Planning Level Code" = 0)THEN EXIT(FALSE);
        IF(InventoryProfileSupply."Planning Flexibility" = InventoryProfileSupply."Planning Flexibility"::None) OR ((ReduceQty <= DampenerQty) AND (InventoryProfileSupply."Planning Level Code" = 0))THEN EXIT(FALSE);
        EXIT(TRUE);
    end;
    local procedure CreateSupply(var SupplyInvtProfile: Record "Inventory Profile"; var DemandInvtProfile: Record "Inventory Profile"; ProjectedInventory: Decimal; IsExceptionOrder: Boolean; RespectPlanningParm: Boolean)
    var
        ReorderQty: Decimal;
    begin
        InitSupply(SupplyInvtProfile, 0, DemandInvtProfile."Due Date");
        ReorderQty:=DemandInvtProfile."Untracked Quantity";
        IF(NOT IsExceptionOrder) OR RespectPlanningParm THEN BEGIN
            IF NOT RespectPlanningParm THEN ReorderQty:=CalcReorderQty(ReorderQty, ProjectedInventory, SupplyInvtProfile."Line No.")
            ELSE IF IsExceptionOrder THEN BEGIN
                    IF DemandInvtProfile."Order Relation" = DemandInvtProfile."Order Relation"::"Safety Stock" THEN // Compensate for Safety Stock offset
 ProjectedInventory:=ProjectedInventory + DemandInvtProfile."Remaining Quantity (Base)";
                    ReorderQty:=CalcReorderQty(ReorderQty, ProjectedInventory, SupplyInvtProfile."Line No.");
                    IF ReorderQty < -ProjectedInventory THEN ReorderQty:=ROUND(-ProjectedInventory / TempSKU."Reorder Quantity" + ExceedROPqty, 1, '>') * TempSKU."Reorder Quantity";
                END;
            ReorderQty+=AdjustReorderQty(ReorderQty, TempSKU, SupplyInvtProfile."Line No.", SupplyInvtProfile."Min. Quantity");
            SupplyInvtProfile."Max. Quantity":=TempSKU."Maximum Order Quantity";
        END;
        UpdateQty(SupplyInvtProfile, ReorderQty);
        IF TempSKU."Maximum Order Quantity" > 0 THEN BEGIN
            IF SupplyInvtProfile."Remaining Quantity (Base)" > TempSKU."Maximum Order Quantity" THEN SupplyInvtProfile."Remaining Quantity (Base)":=TempSKU."Maximum Order Quantity";
            IF SupplyInvtProfile."Untracked Quantity" >= TempSKU."Maximum Order Quantity" THEN SupplyInvtProfile."Untracked Quantity":=SupplyInvtProfile."Untracked Quantity" - ReorderQty + SupplyInvtProfile."Remaining Quantity (Base)";
        END;
        SupplyInvtProfile."Min. Quantity":=SupplyInvtProfile."Remaining Quantity (Base)";
        TransferAttributes(SupplyInvtProfile, DemandInvtProfile);
        SupplyInvtProfile."Is Exception Order":=IsExceptionOrder;
        SupplyInvtProfile.INSERT;
        IF(NOT IsExceptionOrder OR RespectPlanningParm) AND (OverflowLevel > 0)THEN // the new supply might cause overflow in inventory since
 // it wasn't considered when Overflow was calculated
            CheckNewOverflow(SupplyInvtProfile, ProjectedInventory + ReorderQty, ReorderQty, SupplyInvtProfile."Due Date");
    end;
    local procedure CreateDemand(var DemandInvtProfile: Record "Inventory Profile"; var SKU: Record "Stockkeeping Unit"; NeededQuantity: Decimal; NeededDueDate: Date; OrderRelation: Option Normal, "Safety Stock", "Reorder Point")
    begin
        DemandInvtProfile.INIT;
        DemandInvtProfile."Line No.":=NextLineNo;
        DemandInvtProfile."Item No.":=SKU."Item No.";
        DemandInvtProfile."Variant Code":=SKU."Variant Code";
        DemandInvtProfile."Location Code":=SKU."Location Code";
        DemandInvtProfile."Quantity (Base)":=NeededQuantity;
        DemandInvtProfile."Remaining Quantity (Base)":=NeededQuantity;
        DemandInvtProfile.IsSupply:=FALSE;
        DemandInvtProfile."Order Relation":=OrderRelation;
        DemandInvtProfile."Source Type":=0;
        DemandInvtProfile."Untracked Quantity":=NeededQuantity;
        DemandInvtProfile."Due Date":=NeededDueDate;
        DemandInvtProfile."Planning Flexibility":=DemandInvtProfile."Planning Flexibility"::None;
        OnBeforeDemandInvtProfileInsert(DemandInvtProfile, SKU);
        DemandInvtProfile.INSERT;
    end;
    local procedure Track(FromProfile: Record "Inventory Profile"; ToProfile: Record "Inventory Profile"; IsSurplus: Boolean; IssueActionMessage: Boolean; Binding: Enum "Reservation Binding")
    var
        TrkgReservEntryArray: array[6]of Record "Reservation Entry";
        SplitState: Option NoSplit, SplitFromProfile, SplitToProfile, Cancel;
        SplitQty: Decimal;
        SplitQty2: Decimal;
        TrackQty: Decimal;
        DecreaseSupply: Boolean;
    begin
        DecreaseSupply:=FromProfile.IsSupply AND (FromProfile."Action Message" IN[FromProfile."Action Message"::"Change Qty.", FromProfile."Action Message"::"Resched. & Chg. Qty."]) AND (FromProfile."Quantity (Base)" < FromProfile."Original Quantity" * FromProfile."Qty. per Unit of Measure");
        IF((FromProfile."Action Message" = FromProfile."Action Message"::Cancel) AND (FromProfile."Untracked Quantity" = 0)) OR (DecreaseSupply AND IsSurplus)THEN BEGIN
            IsSurplus:=FALSE;
            IF DecreaseSupply THEN FromProfile."Untracked Quantity":=FromProfile."Original Quantity" * FromProfile."Qty. per Unit of Measure" - FromProfile."Quantity (Base)"
            ELSE IF FromProfile.IsSupply THEN FromProfile."Untracked Quantity":=FromProfile."Remaining Quantity" * FromProfile."Qty. per Unit of Measure"
                ELSE
                    FromProfile."Untracked Quantity":=-FromProfile."Remaining Quantity" * FromProfile."Qty. per Unit of Measure";
            FromProfile.TransferToTrackingEntry(TrkgReservEntryArray[1], FALSE);
            TrkgReservEntryArray[3]:=TrkgReservEntryArray[1];
            ReqLine.TransferToTrackingEntry(TrkgReservEntryArray[3], TRUE);
            IF FromProfile.IsSupply THEN TrkgReservEntryArray[3]."Shipment Date":=FromProfile."Due Date"
            ELSE
                TrkgReservEntryArray[3]."Expected Receipt Date":=FromProfile."Due Date";
            SplitState:=SplitState::Cancel;
        END
        ELSE
        BEGIN
            TrackQty:=FromProfile."Untracked Quantity";
            IF FromProfile.IsSupply THEN BEGIN
                IF NOT((FromProfile."Original Quantity" * FromProfile."Qty. per Unit of Measure" > FromProfile."Quantity (Base)") OR (FromProfile."Untracked Quantity" > 0))THEN EXIT;
                SplitQty:=FromProfile."Original Quantity" * FromProfile."Qty. per Unit of Measure" + FromProfile."Untracked Quantity" - FromProfile."Quantity (Base)";
                CASE FromProfile."Action Message" OF FromProfile."Action Message"::"Resched. & Chg. Qty.", FromProfile."Action Message"::Reschedule, FromProfile."Action Message"::New, FromProfile."Action Message"::"Change Qty.": BEGIN
                    IF(SplitQty > 0) AND (SplitQty < TrackQty)THEN BEGIN
                        SplitState:=SplitState::SplitFromProfile;
                        FromProfile.TransferToTrackingEntry(TrkgReservEntryArray[1], (FromProfile."Action Message" = FromProfile."Action Message"::Reschedule) OR (FromProfile."Action Message" = FromProfile."Action Message"::"Resched. & Chg. Qty."));
                        TrkgReservEntryArray[3]:=TrkgReservEntryArray[1];
                        ReqLine.TransferToTrackingEntry(TrkgReservEntryArray[3], TRUE);
                        IF IsSurplus THEN BEGIN
                            TrkgReservEntryArray[3]."Quantity (Base)":=TrackQty - SplitQty;
                            TrkgReservEntryArray[1]."Quantity (Base)":=SplitQty;
                        END
                        ELSE
                        BEGIN
                            TrkgReservEntryArray[1]."Quantity (Base)":=TrackQty - SplitQty;
                            TrkgReservEntryArray[3]."Quantity (Base)":=SplitQty;
                        END;
                        TrkgReservEntryArray[1].Quantity:=ROUND(TrkgReservEntryArray[1]."Quantity (Base)" / TrkgReservEntryArray[1]."Qty. per Unit of Measure", UOMMgt.QtyRndPrecision);
                        TrkgReservEntryArray[3].Quantity:=ROUND(TrkgReservEntryArray[3]."Quantity (Base)" / TrkgReservEntryArray[3]."Qty. per Unit of Measure", UOMMgt.QtyRndPrecision);
                    END
                    ELSE
                    BEGIN
                        FromProfile.TransferToTrackingEntry(TrkgReservEntryArray[1], FALSE);
                        ReqLine.TransferToTrackingEntry(TrkgReservEntryArray[1], TRUE);
                    END;
                    IF IsSurplus THEN BEGIN
                        TrkgReservEntryArray[4]:=TrkgReservEntryArray[1];
                        ReqLine.TransferToTrackingEntry(TrkgReservEntryArray[4], TRUE);
                        TrkgReservEntryArray[4]."Shipment Date":=ReqLine."Due Date";
                    END;
                    ToProfile.TransferToTrackingEntry(TrkgReservEntryArray[2], FALSE);
                END;
                ELSE
                    FromProfile.TransferToTrackingEntry(TrkgReservEntryArray[1], FALSE);
                    ToProfile.TransferToTrackingEntry(TrkgReservEntryArray[2], (ToProfile."Source Type" = DATABASE::"Planning Component") AND (ToProfile."Primary Order Status" > 1)); // Firm Planned, Released Prod.Order
                END;
            END
            ELSE
            BEGIN
                ToProfile.TESTFIELD(IsSupply, TRUE);
                SplitQty:=ToProfile."Remaining Quantity" * ToProfile."Qty. per Unit of Measure" + ToProfile."Untracked Quantity" + FromProfile."Untracked Quantity" - ToProfile."Quantity (Base)";
                IF FromProfile."Source Type" = DATABASE::"Planning Component" THEN BEGIN
                    SplitQty2:=FromProfile."Original Quantity" * FromProfile."Qty. per Unit of Measure";
                    IF FromProfile."Untracked Quantity" < SplitQty2 THEN SplitQty2:=FromProfile."Untracked Quantity";
                    IF SplitQty2 > SplitQty THEN SplitQty2:=SplitQty;
                END;
                IF SplitQty2 > 0 THEN BEGIN
                    ToProfile.TransferToTrackingEntry(TrkgReservEntryArray[5], FALSE);
                    IF ToProfile."Action Message" = ToProfile."Action Message"::New THEN BEGIN
                        ReqLine.TransferToTrackingEntry(TrkgReservEntryArray[5], TRUE);
                        FromProfile.TransferToTrackingEntry(TrkgReservEntryArray[6], FALSE);
                    END
                    ELSE
                        FromProfile.TransferToTrackingEntry(TrkgReservEntryArray[6], TRUE);
                    TrkgReservEntryArray[5]."Quantity (Base)":=SplitQty2;
                    TrkgReservEntryArray[5].Quantity:=ROUND(TrkgReservEntryArray[5]."Quantity (Base)" / TrkgReservEntryArray[5]."Qty. per Unit of Measure", UOMMgt.QtyRndPrecision);
                    FromProfile."Untracked Quantity":=FromProfile."Untracked Quantity" - SplitQty2;
                    TrackQty:=TrackQty - SplitQty2;
                    SplitQty:=SplitQty - SplitQty2;
                    PrepareTempTracking(TrkgReservEntryArray[5], TrkgReservEntryArray[6], IsSurplus, IssueActionMessage, Binding);
                END;
                IF(ToProfile."Action Message" <> ToProfile."Action Message"::" ") AND (SplitQty < TrackQty)THEN BEGIN
                    IF(SplitQty > 0) AND (SplitQty < TrackQty)THEN BEGIN
                        SplitState:=SplitState::SplitToProfile;
                        ToProfile.TransferToTrackingEntry(TrkgReservEntryArray[2], (FromProfile."Action Message" = FromProfile."Action Message"::Reschedule) OR (FromProfile."Action Message" = FromProfile."Action Message"::"Resched. & Chg. Qty."));
                        TrkgReservEntryArray[3]:=TrkgReservEntryArray[2];
                        ReqLine.TransferToTrackingEntry(TrkgReservEntryArray[2], TRUE);
                        TrkgReservEntryArray[2]."Quantity (Base)":=TrackQty - SplitQty;
                        TrkgReservEntryArray[3]."Quantity (Base)":=SplitQty;
                        TrkgReservEntryArray[2].Quantity:=ROUND(TrkgReservEntryArray[2]."Quantity (Base)" / TrkgReservEntryArray[2]."Qty. per Unit of Measure", UOMMgt.QtyRndPrecision);
                        TrkgReservEntryArray[3].Quantity:=ROUND(TrkgReservEntryArray[3]."Quantity (Base)" / TrkgReservEntryArray[3]."Qty. per Unit of Measure", UOMMgt.QtyRndPrecision);
                    END
                    ELSE
                    BEGIN
                        ToProfile.TransferToTrackingEntry(TrkgReservEntryArray[2], FALSE);
                        ReqLine.TransferToTrackingEntry(TrkgReservEntryArray[2], TRUE);
                    END;
                END
                ELSE
                    ToProfile.TransferToTrackingEntry(TrkgReservEntryArray[2], FALSE);
                FromProfile.TransferToTrackingEntry(TrkgReservEntryArray[1], FALSE);
            END;
        END;
        CASE SplitState OF SplitState::NoSplit: PrepareTempTracking(TrkgReservEntryArray[1], TrkgReservEntryArray[2], IsSurplus, IssueActionMessage, Binding);
        SplitState::SplitFromProfile: IF IsSurplus THEN BEGIN
                PrepareTempTracking(TrkgReservEntryArray[1], TrkgReservEntryArray[4], FALSE, IssueActionMessage, Binding);
                PrepareTempTracking(TrkgReservEntryArray[3], TrkgReservEntryArray[4], TRUE, IssueActionMessage, Binding);
            END
            ELSE
            BEGIN
                TrkgReservEntryArray[4]:=TrkgReservEntryArray[2];
                PrepareTempTracking(TrkgReservEntryArray[1], TrkgReservEntryArray[2], IsSurplus, IssueActionMessage, Binding);
                PrepareTempTracking(TrkgReservEntryArray[3], TrkgReservEntryArray[4], IsSurplus, IssueActionMessage, Binding);
            END;
        SplitState::SplitToProfile: BEGIN
            TrkgReservEntryArray[4]:=TrkgReservEntryArray[1];
            PrepareTempTracking(TrkgReservEntryArray[2], TrkgReservEntryArray[1], IsSurplus, IssueActionMessage, Binding);
            PrepareTempTracking(TrkgReservEntryArray[3], TrkgReservEntryArray[4], IsSurplus, IssueActionMessage, Binding);
        END;
        SplitState::Cancel: PrepareTempTracking(TrkgReservEntryArray[1], TrkgReservEntryArray[3], IsSurplus, IssueActionMessage, Binding);
        END;
    end;
    local procedure PrepareTempTracking(var FromTrkgReservEntry: Record "Reservation Entry"; var ToTrkgReservEntry: Record "Reservation Entry"; IsSurplus: Boolean; IssueActionMessage: Boolean; Binding: Enum "Reservation Binding")
    begin
        IF NOT IsSurplus THEN BEGIN
            ToTrkgReservEntry."Quantity (Base)":=-FromTrkgReservEntry."Quantity (Base)";
            ToTrkgReservEntry.Quantity:=ROUND(ToTrkgReservEntry."Quantity (Base)" / ToTrkgReservEntry."Qty. per Unit of Measure", UOMMgt.QtyRndPrecision);
        END
        ELSE
            ToTrkgReservEntry."Suppressed Action Msg.":=NOT IssueActionMessage;
        ToTrkgReservEntry.Positive:=ToTrkgReservEntry."Quantity (Base)" > 0;
        FromTrkgReservEntry.Positive:=FromTrkgReservEntry."Quantity (Base)" > 0;
        FromTrkgReservEntry.Binding:=Binding;
        ToTrkgReservEntry.Binding:=Binding;
        IF IsSurplus OR (ToTrkgReservEntry."Reservation Status" = ToTrkgReservEntry."Reservation Status"::Surplus)THEN BEGIN
            FromTrkgReservEntry."Reservation Status":=FromTrkgReservEntry."Reservation Status"::Surplus;
            FromTrkgReservEntry."Suppressed Action Msg.":=ToTrkgReservEntry."Suppressed Action Msg.";
            InsertTempTracking(FromTrkgReservEntry, ToTrkgReservEntry);
            EXIT;
        END;
        IF FromTrkgReservEntry."Reservation Status" = FromTrkgReservEntry."Reservation Status"::Surplus THEN BEGIN
            ToTrkgReservEntry."Reservation Status":=ToTrkgReservEntry."Reservation Status"::Surplus;
            ToTrkgReservEntry."Suppressed Action Msg.":=FromTrkgReservEntry."Suppressed Action Msg.";
            InsertTempTracking(ToTrkgReservEntry, FromTrkgReservEntry);
            EXIT;
        END;
        InsertTempTracking(FromTrkgReservEntry, ToTrkgReservEntry);
    end;
    local procedure InsertTempTracking(var FromTrkgReservEntry: Record "Reservation Entry"; var ToTrkgReservEntry: Record "Reservation Entry")
    var
        NextEntryNo: Integer;
        ShouldInsert: Boolean;
    begin
        IF FromTrkgReservEntry."Quantity (Base)" = 0 THEN EXIT;
        NextEntryNo:=TempTrkgReservEntry."Entry No." + 1;
        IF FromTrkgReservEntry."Reservation Status" = FromTrkgReservEntry."Reservation Status"::Surplus THEN BEGIN
            TempTrkgReservEntry:=FromTrkgReservEntry;
            TempTrkgReservEntry."Entry No.":=NextEntryNo;
            SetQtyToHandle(TempTrkgReservEntry);
            TempTrkgReservEntry.INSERT;
        END
        ELSE
        BEGIN
            MatchReservationEntries(FromTrkgReservEntry, ToTrkgReservEntry);
            IF FromTrkgReservEntry.Positive THEN BEGIN
                FromTrkgReservEntry."Shipment Date":=ToTrkgReservEntry."Shipment Date";
                IF ToTrkgReservEntry."Source Type" = DATABASE::"Item Ledger Entry" THEN ToTrkgReservEntry."Shipment Date":=DMY2DATE(31, 12, 9999);
                ToTrkgReservEntry."Expected Receipt Date":=FromTrkgReservEntry."Expected Receipt Date";
            END
            ELSE
            BEGIN
                ToTrkgReservEntry."Shipment Date":=FromTrkgReservEntry."Shipment Date";
                IF FromTrkgReservEntry."Source Type" = DATABASE::"Item Ledger Entry" THEN FromTrkgReservEntry."Shipment Date":=DMY2DATE(31, 12, 9999);
                FromTrkgReservEntry."Expected Receipt Date":=ToTrkgReservEntry."Expected Receipt Date";
            END;
            IF FromTrkgReservEntry.Positive THEN ShouldInsert:=ShouldInsertTrackingEntry(FromTrkgReservEntry)
            ELSE
                ShouldInsert:=ShouldInsertTrackingEntry(ToTrkgReservEntry);
            IF ShouldInsert THEN BEGIN
                TempTrkgReservEntry:=FromTrkgReservEntry;
                TempTrkgReservEntry."Entry No.":=NextEntryNo;
                SetQtyToHandle(TempTrkgReservEntry);
                TempTrkgReservEntry.INSERT;
                TempTrkgReservEntry:=ToTrkgReservEntry;
                TempTrkgReservEntry."Entry No.":=NextEntryNo;
                SetQtyToHandle(TempTrkgReservEntry);
                TempTrkgReservEntry.INSERT;
            END;
        END;
    end;
    local procedure SetQtyToHandle(var TrkgReservEntry: Record "Reservation Entry")
    var
        PickedQty: Decimal;
    begin
        IF NOT TrkgReservEntry.TrackingExists THEN EXIT;
        PickedQty:=QtyPickedForSourceDocument(TrkgReservEntry);
        IF PickedQty <> 0 THEN BEGIN
            TrkgReservEntry."Qty. to Handle (Base)":=PickedQty;
            TrkgReservEntry."Qty. to Invoice (Base)":=PickedQty;
        END
        ELSE
        BEGIN
            TrkgReservEntry."Qty. to Handle (Base)":=TrkgReservEntry."Quantity (Base)";
            TrkgReservEntry."Qty. to Invoice (Base)":=TrkgReservEntry."Quantity (Base)";
        END;
    end;
    local procedure CommitTracking()
    var
        PrevTempEntryNo: Integer;
        PrevInsertedEntryNo: Integer;
    begin
        IF NOT TempTrkgReservEntry.FIND('-')THEN EXIT;
        REPEAT ReservEntry:=TempTrkgReservEntry;
            IF TempTrkgReservEntry."Entry No." = PrevTempEntryNo THEN ReservEntry."Entry No.":=PrevInsertedEntryNo
            ELSE
                ReservEntry."Entry No.":=0;
            ReservEntry.UpdateItemTracking;
            UpdateAppliedItemEntry(ReservEntry);
            ReservEntry.INSERT;
            PrevTempEntryNo:=TempTrkgReservEntry."Entry No.";
            PrevInsertedEntryNo:=ReservEntry."Entry No.";
            TempTrkgReservEntry.DELETE;
        UNTIL TempTrkgReservEntry.NEXT = 0;
        CLEAR(TempTrkgReservEntry);
    end;
    local procedure MaintainPlanningLine(var SupplyInvtProfile: Record "Inventory Profile"; DemandInvtProfile: Record "Inventory Profile"; NewPhase: Option " ", "Line Created", "Routing Created", Exploded, Obsolete; Direction: Option Forward, Backward)
    var
        PurchaseLine: Record "Purchase Line";
        ProdOrderLine: Record "Prod. Order Line";
        AsmHeader: Record "Assembly Header";
        TransLine: Record "Transfer Line";
        CrntSupplyInvtProfile: Record "Inventory Profile";
        PlanLineNo: Integer;
        RecalculationRequired: Boolean;
    begin
        IF(NewPhase = NewPhase::"Line Created") OR (SupplyInvtProfile."Planning Line Phase" < SupplyInvtProfile."Planning Line Phase"::"Line Created")THEN IF SupplyInvtProfile."Planning Line No." = 0 THEN BEGIN
                ReqLine.BlockDynamicTracking(TRUE);
                IF ReqLine.FINDLAST THEN PlanLineNo:=ReqLine."Line No." + 10000
                ELSE
                    PlanLineNo:=10000;
                ReqLine.INIT;
                //test
                ReqLine."Worksheet Template Name":=CurrTemplateName;
                ReqLine."Journal Batch Name":=CurrWorksheetName;
                ReqLine."Line No.":=PlanLineNo;
                ReqLine.Type:=ReqLine.Type::Item;
                ReqLine."No.":=SupplyInvtProfile."Item No.";
                ReqLine."Variant Code":=SupplyInvtProfile."Variant Code";
                ReqLine."Location Code":=SupplyInvtProfile."Location Code";
                ReqLine."Bin Code":=SupplyInvtProfile."Bin Code";
                ReqLine."Planning Line Origin":=ReqLine."Planning Line Origin"::Planning;
                IF SupplyInvtProfile."Action Message" = SupplyInvtProfile."Action Message"::New THEN BEGIN
                    ReqLine."Order Date":=SupplyInvtProfile."Due Date";
                    ReqLine."Planning Level":=SupplyInvtProfile."Planning Level Code";
                    CASE TempSKU."Replenishment System" OF TempSKU."Replenishment System"::Purchase: ReqLine."Ref. Order Type":=ReqLine."Ref. Order Type"::Purchase;
                    TempSKU."Replenishment System"::"Prod. Order": BEGIN
                        ReqLine."Ref. Order Type":=ReqLine."Ref. Order Type"::"Prod. Order";
                        IF ReqLine."Planning Level" > 0 THEN BEGIN
                            ReqLine."Ref. Order Status":=SupplyInvtProfile."Primary Order Status";
                            ReqLine."Ref. Order No.":=SupplyInvtProfile."Primary Order No.";
                        END;
                    END;
                    TempSKU."Replenishment System"::Assembly: ReqLine."Ref. Order Type":=ReqLine."Ref. Order Type"::Assembly;
                    TempSKU."Replenishment System"::Transfer: ReqLine."Ref. Order Type":=ReqLine."Ref. Order Type"::Transfer;
                    END;
                    ReqLine.VALIDATE(ReqLine."No.");
                    ReqLine.VALIDATE(ReqLine."Unit of Measure Code", SupplyInvtProfile."Unit of Measure Code");
                    ReqLine."Starting Time":=ManufacturingSetup."Normal Starting Time";
                    ReqLine."Ending Time":=ManufacturingSetup."Normal Ending Time";
                END
                ELSE
                    CASE SupplyInvtProfile."Source Type" OF DATABASE::"Purchase Line": SetPurchase(PurchaseLine, SupplyInvtProfile);
                    DATABASE::"Prod. Order Line": SetProdOrder(ProdOrderLine, SupplyInvtProfile);
                    DATABASE::"Assembly Header": SetAssembly(AsmHeader, SupplyInvtProfile);
                    DATABASE::"Transfer Line": SetTransfer(TransLine, SupplyInvtProfile);
                    END;
                AdjustPlanLine(SupplyInvtProfile);
                ReqLine."Accept Action Message":=TRUE;
                ReqLine."Routing Reference No.":=ReqLine."Line No.";
                ReqLine.UpdateDatetime;
                ReqLine."MPS Order":=SupplyInvtProfile."MPS Order";
                OnMaintainPlanningLineOnBeforeReqLineInsert(ReqLine, SupplyInvtProfile, PlanToDate, CurrForecast, NewPhase, Direction, DemandInvtProfile);
                ReqLine.INSERT;
                //test
                OnMaintainPlanningLineOnAfterReqLineInsert(ReqLine);
                SupplyInvtProfile."Planning Line No.":=ReqLine."Line No.";
                IF NewPhase = NewPhase::"Line Created" THEN SupplyInvtProfile."Planning Line Phase":=SupplyInvtProfile."Planning Line Phase"::"Line Created";
            END
            ELSE
            BEGIN
                IF SupplyInvtProfile."Planning Line No." <> ReqLine."Line No." THEN ReqLine.GET(CurrTemplateName, CurrWorksheetName, SupplyInvtProfile."Planning Line No.");
                ReqLine.BlockDynamicTracking(TRUE);
                AdjustPlanLine(SupplyInvtProfile);
                IF NewPhase = NewPhase::"Line Created" THEN ReqLine.MODIFY;
            END;
        OnMaintainPlanningLineOnAfterLineCreated(SupplyInvtProfile, ReqLine);
        IF(NewPhase = NewPhase::"Routing Created") OR ((NewPhase > NewPhase::"Routing Created") AND (SupplyInvtProfile."Planning Line Phase" < SupplyInvtProfile."Planning Line Phase"::"Routing Created"))THEN BEGIN
            ReqLine.BlockDynamicTracking(TRUE);
            IF SupplyInvtProfile."Planning Line No." <> ReqLine."Line No." THEN ReqLine.GET(CurrTemplateName, CurrWorksheetName, SupplyInvtProfile."Planning Line No.");
            AdjustPlanLine(SupplyInvtProfile);
            IF ReqLine.Quantity > 0 THEN BEGIN
                IF SupplyInvtProfile."Starting Date" <> 0D THEN ReqLine."Starting Date":=SupplyInvtProfile."Starting Date"
                ELSE
                    ReqLine."Starting Date":=SupplyInvtProfile."Due Date";
                GetRouting(ReqLine);
                RecalculationRequired:=TRUE;
                IF NewPhase = NewPhase::"Routing Created" THEN SupplyInvtProfile."Planning Line Phase":=SupplyInvtProfile."Planning Line Phase"::"Routing Created";
            END;
            ReqLine.MODIFY;
        END;
        IF NewPhase = NewPhase::Exploded THEN BEGIN
            IF SupplyInvtProfile."Planning Line No." <> ReqLine."Line No." THEN ReqLine.GET(CurrTemplateName, CurrWorksheetName, SupplyInvtProfile."Planning Line No.");
            ReqLine.BlockDynamicTracking(TRUE);
            AdjustPlanLine(SupplyInvtProfile);
            IF ReqLine.Quantity = 0 THEN IF ReqLine."Action Message" = ReqLine."Action Message"::New THEN BEGIN
                    ReqLine.BlockDynamicTracking(TRUE);
                    ReqLine.DELETE(TRUE);
                    RecalculationRequired:=FALSE;
                END
                ELSE
                    DisableRelations
            ELSE
            BEGIN
                GetComponents(ReqLine);
                RecalculationRequired:=TRUE;
            END;
            IF(ReqLine."Ref. Order Type" = ReqLine."Ref. Order Type"::Transfer) AND NOT((ReqLine.Quantity = 0) AND (ReqLine."Action Message" = ReqLine."Action Message"::New))THEN BEGIN
                AdjustTransferDates(ReqLine);
                IF ReqLine."Action Message" = ReqLine."Action Message"::New THEN BEGIN
                    CrntSupplyInvtProfile.COPY(SupplyInvtProfile);
                    SupplyInvtProfile.INIT;
                    SupplyInvtProfile."Line No.":=NextLineNo;
                    SupplyInvtProfile."Item No.":=ReqLine."No.";
                    SupplyInvtProfile.TransferFromOutboundTransfPlan(ReqLine, TempItemTrkgEntry);
                    SupplyInvtProfile."Lot No.":=CrntSupplyInvtProfile."Lot No.";
                    SupplyInvtProfile."Serial No.":=CrntSupplyInvtProfile."Serial No.";
                    IF SupplyInvtProfile.IsSupply THEN SupplyInvtProfile.ChangeSign;
                    SupplyInvtProfile.INSERT;
                    SupplyInvtProfile.COPY(CrntSupplyInvtProfile);
                END
                ELSE
                    SynchronizeTransferProfiles(SupplyInvtProfile, ReqLine);
            END;
        END;
        IF RecalculationRequired THEN BEGIN
            Recalculate(ReqLine, Direction, ((SupplyInvtProfile."Planning Line Phase" < SupplyInvtProfile."Planning Line Phase"::"Routing Created") OR (ReqLine."Action Message" = ReqLine."Action Message"::New)) AND (ReqLine."Ref. Order Type" = ReqLine."Ref. Order Type"::"Prod. Order"));
            ReqLine.UpdateDatetime;
            ReqLine.MODIFY;
            SupplyInvtProfile."Starting Date":=ReqLine."Starting Date";
            SupplyInvtProfile."Due Date":=ReqLine."Due Date";
        END;
        IF NewPhase = NewPhase::Obsolete THEN BEGIN
            IF SupplyInvtProfile."Planning Line No." <> ReqLine."Line No." THEN ReqLine.GET(CurrTemplateName, CurrWorksheetName, SupplyInvtProfile."Planning Line No.");
            ReqLine.DELETE(TRUE);
            SupplyInvtProfile."Planning Line No.":=0;
            SupplyInvtProfile."Planning Line Phase":=SupplyInvtProfile."Planning Line Phase"::" ";
        END;
        SupplyInvtProfile.MODIFY;
    end;
    procedure AdjustReorderQty(OrderQty: Decimal; SKU: Record "Stockkeeping Unit"; SupplyLineNo: Integer; MinQty: Decimal): Decimal var
        DeltaQty: Decimal;
        Rounding: Decimal;
    begin
        // Copy of this procedure exists in COD5400- Available Management
        IF OrderQty <= 0 THEN EXIT(0);
        IF(SKU."Maximum Order Quantity" < OrderQty) AND (SKU."Maximum Order Quantity" <> 0) AND (SKU."Maximum Order Quantity" > MinQty)THEN BEGIN
            DeltaQty:=SKU."Maximum Order Quantity" - OrderQty;
            PlanningTransparency.LogSurplus(SupplyLineNo, 0, DATABASE::Item, TempSKU."Item No.", DeltaQty, SurplusType::MaxOrder);
        END
        ELSE
            DeltaQty:=0;
        IF SKU."Minimum Order Quantity" > (OrderQty + DeltaQty)THEN BEGIN
            DeltaQty:=SKU."Minimum Order Quantity" - OrderQty;
            PlanningTransparency.LogSurplus(SupplyLineNo, 0, DATABASE::Item, TempSKU."Item No.", SKU."Minimum Order Quantity", SurplusType::MinOrder);
        END;
        IF SKU."Order Multiple" <> 0 THEN BEGIN
            Rounding:=ROUND(OrderQty + DeltaQty, SKU."Order Multiple", '>') - (OrderQty + DeltaQty);
            DeltaQty+=Rounding;
            IF DeltaQty <> 0 THEN PlanningTransparency.LogSurplus(SupplyLineNo, 0, DATABASE::Item, TempSKU."Item No.", Rounding, SurplusType::OrderMultiple);
        END;
        EXIT(DeltaQty);
    end;
    local procedure CalcInventoryProfileRemainingQty(var InventoryProfile: Record "Inventory Profile"; DocumentNo: Code[20]): Decimal begin
        InventoryProfile.SETRANGE(InventoryProfile."Source Type", DATABASE::"Sales Line");
        InventoryProfile.SETRANGE(InventoryProfile."Ref. Blanket Order No.", DocumentNo);
        InventoryProfile.CALCSUMS(InventoryProfile."Remaining Quantity (Base)");
        EXIT(InventoryProfile."Remaining Quantity (Base)");
    end;
    local procedure CalcReorderQty(NeededQty: Decimal; ProjectedInventory: Decimal; SupplyLineNo: Integer)QtyToOrder: Decimal var
        Item: Record "Item";
        SKU: Record "Stockkeeping Unit";
    begin
        // Calculate qty to order:
        // If Max:   QtyToOrder = MaxInv - ProjInvLevel
        // If Fixed: QtyToOrder = FixedReorderQty
        // Copy of this procedure exists in COD5400- Available Management
        CASE TempSKU."Reordering Policy" OF TempSKU."Reordering Policy"::"Maximum Qty.": BEGIN
            IF TempSKU."Maximum Inventory" <= TempSKU."Reorder Point" THEN BEGIN
                IF PlanningResilicency THEN IF SKU.GET(TempSKU."Location Code", TempSKU."Item No.", TempSKU."Variant Code")THEN ReqLine.SetResiliencyError(STRSUBSTNO(Text004, SKU.FIELDCAPTION("Maximum Inventory"), SKU."Maximum Inventory", SKU.TABLECAPTION, SKU."Location Code", SKU."Item No.", SKU."Variant Code", SKU.FIELDCAPTION("Reorder Point"), SKU."Reorder Point"), DATABASE::"Stockkeeping Unit", SKU.GETPOSITION)
                    ELSE IF Item.GET(TempSKU."Item No.")THEN ReqLine.SetResiliencyError(STRSUBSTNO(Text005, Item.FIELDCAPTION("Maximum Inventory"), Item."Maximum Inventory", Item.TABLECAPTION, Item."No.", Item.FIELDCAPTION("Reorder Point"), Item."Reorder Point"), DATABASE::Item, Item.GETPOSITION);
                TempSKU.TESTFIELD("Maximum Inventory", TempSKU."Reorder Point" + 1); // Assertion
            END;
            QtyToOrder:=TempSKU."Maximum Inventory" - ProjectedInventory;
            PlanningTransparency.LogSurplus(SupplyLineNo, 0, DATABASE::Item, TempSKU."Item No.", QtyToOrder, SurplusType::MaxInventory);
        END;
        TempSKU."Reordering Policy"::"Fixed Reorder Qty.": BEGIN
            IF PlanningResilicency AND (TempSKU."Reorder Quantity" = 0)THEN IF SKU.GET(TempSKU."Location Code", TempSKU."Item No.", TempSKU."Variant Code")THEN ReqLine.SetResiliencyError(STRSUBSTNO(Text004, SKU.FIELDCAPTION("Reorder Quantity"), 0, SKU.TABLECAPTION, SKU."Location Code", SKU."Item No.", SKU."Variant Code", SKU.FIELDCAPTION("Reordering Policy"), SKU."Reordering Policy"), DATABASE::"Stockkeeping Unit", SKU.GETPOSITION)
                ELSE IF Item.GET(TempSKU."Item No.")THEN ReqLine.SetResiliencyError(STRSUBSTNO(Text005, Item.FIELDCAPTION("Reorder Quantity"), 0, Item.TABLECAPTION, Item."No.", Item.FIELDCAPTION("Reordering Policy"), Item."Reordering Policy"), DATABASE::Item, Item.GETPOSITION);
            TempSKU.TESTFIELD("Reorder Quantity"); // Assertion
            QtyToOrder:=TempSKU."Reorder Quantity";
            PlanningTransparency.LogSurplus(SupplyLineNo, 0, DATABASE::Item, TempSKU."Item No.", QtyToOrder, SurplusType::FixedOrderQty);
        END;
        ELSE
            QtyToOrder:=NeededQty;
        END;
    end;
    local procedure CalcOrderQty(NeededQty: Decimal; ProjectedInventory: Decimal; SupplyLineNo: Integer)QtyToOrder: Decimal begin
        QtyToOrder:=CalcReorderQty(NeededQty, ProjectedInventory, SupplyLineNo);
        // Ensure that QtyToOrder is large enough to exceed ROP:
        IF QtyToOrder <= (TempSKU."Reorder Point" - ProjectedInventory)THEN QtyToOrder:=ROUND((TempSKU."Reorder Point" - ProjectedInventory) / TempSKU."Reorder Quantity" + 0.000000001, 1, '>') * TempSKU."Reorder Quantity";
    end;
    local procedure CalcSalesOrderQty(AsmLine: Record "Assembly Line")QtyOnSalesOrder: Decimal var
        SalesOrderLine: Record "Sales Line";
        ATOLink: Record "Assemble-to-Order Link";
    begin
        QtyOnSalesOrder:=0;
        ATOLink.GET(AsmLine."Document Type", AsmLine."Document No.");
        SalesOrderLine.SETCURRENTKEY("Document Type", "Blanket Order No.", "Blanket Order Line No.");
        SalesOrderLine.SETRANGE("Document Type", SalesOrderLine."Document Type"::Order);
        SalesOrderLine.SETRANGE("Blanket Order No.", ATOLink."Document No.");
        SalesOrderLine.SETRANGE("Blanket Order Line No.", ATOLink."Document Line No.");
        IF SalesOrderLine.FIND('-')THEN REPEAT QtyOnSalesOrder+=SalesOrderLine."Quantity (Base)";
            UNTIL SalesOrderLine.NEXT = 0;
    end;
    local procedure AdjustPlanLine(var Supply: Record "Inventory Profile")
    begin
        OnBeforeAdjustPlanLine(ReqLine, Supply);
        ReqLine."Action Message":=Supply."Action Message";
        ReqLine.BlockDynamicTracking(TRUE);
        IF Supply."Action Message" IN[Supply."Action Message"::New, Supply."Action Message"::"Change Qty.", Supply."Action Message"::Reschedule, Supply."Action Message"::"Resched. & Chg. Qty.", Supply."Action Message"::Cancel]THEN BEGIN
            IF Supply."Qty. per Unit of Measure" = 0 THEN Supply."Qty. per Unit of Measure":=1;
            ReqLine.VALIDATE(Quantity, ROUND(Supply."Remaining Quantity (Base)" / Supply."Qty. per Unit of Measure", UOMMgt.QtyRndPrecision));
            ReqLine."Original Quantity":=Supply."Original Quantity";
            ReqLine."Net Quantity (Base)":=(ReqLine."Remaining Quantity" - ReqLine."Original Quantity") * ReqLine."Qty. per Unit of Measure";
        END;
        ReqLine."Original Due Date":=Supply."Original Due Date";
        ReqLine."Due Date":=Supply."Due Date";
        IF Supply."Planning Level Code" = 0 THEN ReqLine."Ending Date":=LeadTimeMgt.PlannedEndingDate(Supply."Item No.", Supply."Location Code", Supply."Variant Code", Supply."Due Date", '', ReqLine."Ref. Order Type")
        ELSE
        BEGIN
            ReqLine."Ending Date":=Supply."Due Date";
            ReqLine."Ending Time":=Supply."Due Time";
        END;
        IF(ReqLine."Starting Date" = 0D) OR (ReqLine."Starting Date" > ReqLine."Ending Date")THEN ReqLine."Starting Date":=ReqLine."Ending Date";
    end;
    local procedure DisableRelations()
    var
        PlanningComponent: Record "Planning Component";
        PlanningRtngLine: Record "Planning Routing Line";
        ProdOrderCapNeed: Record "Prod. Order Capacity Need";
    begin
        IF ReqLine.Type <> ReqLine.Type::Item THEN EXIT;
        PlanningComponent.SETRANGE("Worksheet Template Name", ReqLine."Worksheet Template Name");
        PlanningComponent.SETRANGE("Worksheet Batch Name", ReqLine."Journal Batch Name");
        PlanningComponent.SETRANGE("Worksheet Line No.", ReqLine."Line No.");
        IF PlanningComponent.FIND('-')THEN REPEAT PlanningComponent.BlockDynamicTracking(FALSE);
                PlanningComponent.DELETE(TRUE);
            UNTIL PlanningComponent.NEXT = 0;
        PlanningRtngLine.SETRANGE("Worksheet Template Name", ReqLine."Worksheet Template Name");
        PlanningRtngLine.SETRANGE("Worksheet Batch Name", ReqLine."Journal Batch Name");
        PlanningRtngLine.SETRANGE("Worksheet Line No.", ReqLine."Line No.");
        PlanningRtngLine.DELETEALL;
        ProdOrderCapNeed.SETCURRENTKEY(ProdOrderCapNeed."Worksheet Template Name", ProdOrderCapNeed."Worksheet Batch Name", ProdOrderCapNeed."Worksheet Line No.");
        ProdOrderCapNeed.SETRANGE(ProdOrderCapNeed."Worksheet Template Name", ReqLine."Worksheet Template Name");
        ProdOrderCapNeed.SETRANGE(ProdOrderCapNeed."Worksheet Batch Name", ReqLine."Journal Batch Name");
        ProdOrderCapNeed.SETRANGE(ProdOrderCapNeed."Worksheet Line No.", ReqLine."Line No.");
        ProdOrderCapNeed.DELETEALL;
        ProdOrderCapNeed.RESET;
        ProdOrderCapNeed.SETCURRENTKEY(ProdOrderCapNeed.Status, ProdOrderCapNeed."Prod. Order No.", ProdOrderCapNeed.Active);
        ProdOrderCapNeed.SETRANGE(ProdOrderCapNeed.Status, ReqLine."Ref. Order Status");
        ProdOrderCapNeed.SETRANGE(ProdOrderCapNeed."Prod. Order No.", ReqLine."Ref. Order No.");
        ProdOrderCapNeed.SETRANGE(ProdOrderCapNeed.Active, TRUE);
        ProdOrderCapNeed.MODIFYALL(ProdOrderCapNeed.Active, FALSE);
    end;
    local procedure SynchronizeTransferProfiles(var InventoryProfile: Record "Inventory Profile"; var TransferReqLine: Record "Requisition Line")
    var
        SupplyInvtProfile: Record "Inventory Profile";
    begin
        IF InventoryProfile."Transfer Location Not Planned" THEN EXIT;
        SupplyInvtProfile.COPY(InventoryProfile);
        IF GetTransferSisterProfile(SupplyInvtProfile, InventoryProfile)THEN BEGIN
            TransferReqLineToInvProfiles(InventoryProfile, TransferReqLine);
            InventoryProfile.MODIFY;
        END;
        InventoryProfile.COPY(SupplyInvtProfile);
    end;
    local procedure TransferReqLineToInvProfiles(var InventoryProfile: Record "Inventory Profile"; var TransferReqLine: Record "Requisition Line")
    begin
        InventoryProfile.TESTFIELD(InventoryProfile."Location Code", TransferReqLine."Transfer-from Code");
        InventoryProfile."Min. Quantity":=InventoryProfile."Remaining Quantity (Base)";
        InventoryProfile."Original Quantity":=TransferReqLine."Original Quantity";
        InventoryProfile.Quantity:=TransferReqLine.Quantity;
        InventoryProfile."Remaining Quantity":=TransferReqLine.Quantity;
        InventoryProfile."Quantity (Base)":=TransferReqLine."Quantity (Base)";
        InventoryProfile."Remaining Quantity (Base)":=TransferReqLine."Quantity (Base)";
        InventoryProfile."Untracked Quantity":=TransferReqLine."Quantity (Base)";
        InventoryProfile."Unit of Measure Code":=TransferReqLine."Unit of Measure Code";
        InventoryProfile."Qty. per Unit of Measure":=TransferReqLine."Qty. per Unit of Measure";
        InventoryProfile."Due Date":=TransferReqLine."Transfer Shipment Date";
    end;
    local procedure SyncTransferDemandWithReqLine(var InventoryProfile: Record "Inventory Profile"; LocationCode: Code[10])
    var
        TransferReqLine: Record "Requisition Line";
    begin
        TransferReqLine.SETRANGE(TransferReqLine."Ref. Order Type", TransferReqLine."Ref. Order Type"::Transfer);
        TransferReqLine.SETRANGE(TransferReqLine."Ref. Order No.", InventoryProfile."Source ID");
        TransferReqLine.SETRANGE(TransferReqLine."Ref. Line No.", InventoryProfile."Source Ref. No.");
        TransferReqLine.SETRANGE(TransferReqLine."Transfer-from Code", InventoryProfile."Location Code");
        TransferReqLine.SETRANGE(TransferReqLine."Location Code", LocationCode);
        TransferReqLine.SETFILTER(TransferReqLine."Action Message", '<>%1', TransferReqLine."Action Message"::New);
        IF TransferReqLine.FINDFIRST THEN TransferReqLineToInvProfiles(InventoryProfile, TransferReqLine);
    end;
    local procedure GetTransferSisterProfile(CurrInvProfile: Record "Inventory Profile"; var SisterInvProfile: Record "Inventory Profile")Ok: Boolean begin
        // Finds the invprofile which represents the opposite side of a transfer order.
        IF(CurrInvProfile."Source Type" <> DATABASE::"Transfer Line") OR (CurrInvProfile."Action Message" = CurrInvProfile."Action Message"::New)THEN EXIT(FALSE);
        CLEAR(SisterInvProfile);
        SisterInvProfile.SETRANGE(SisterInvProfile."Source Type", DATABASE::"Transfer Line");
        SisterInvProfile.SETRANGE(SisterInvProfile."Source ID", CurrInvProfile."Source ID");
        SisterInvProfile.SETRANGE(SisterInvProfile."Source Ref. No.", CurrInvProfile."Source Ref. No.");
        SisterInvProfile.SETRANGE(SisterInvProfile."Lot No.", CurrInvProfile."Lot No.");
        SisterInvProfile.SETRANGE(SisterInvProfile."Serial No.", CurrInvProfile."Serial No.");
        SisterInvProfile.SETRANGE(SisterInvProfile.IsSupply, NOT CurrInvProfile.IsSupply);
        Ok:=SisterInvProfile.FIND('-');
        // Assertion: only 1 outbound transfer record may exist:
        IF Ok THEN IF SisterInvProfile.NEXT <> 0 THEN ERROR(Text001, SisterInvProfile.TABLECAPTION);
        EXIT;
    end;
    local procedure AdjustTransferDates(var TransferReqLine: Record "Requisition Line")
    var
        TransferRoute: Record "Transfer Route";
        ShippingAgentServices: Record "Shipping Agent Services";
        Location: Record "Location";
        SKU: Record "Stockkeeping Unit";
        ShippingTime: DateFormula;
        OutboundWhseTime: DateFormula;
        InboundWhseTime: DateFormula;
        OK: Boolean;
    begin
        // Used for planning lines handling transfer orders.
        // "Ending Date", Starting Date and "Transfer Shipment Date" are calculated backwards from "Due Date".
        TransferReqLine.TESTFIELD("Ref. Order Type", TransferReqLine."Ref. Order Type"::Transfer);
        OK:=Location.GET(TransferReqLine."Transfer-from Code");
        IF PlanningResilicency AND NOT OK THEN IF SKU.GET(TransferReqLine."Location Code", TransferReqLine."No.", TransferReqLine."Variant Code")THEN ReqLine.SetResiliencyError(STRSUBSTNO(Text003, SKU.FIELDCAPTION("Transfer-from Code"), SKU.TABLECAPTION, SKU."Location Code", SKU."Item No.", SKU."Variant Code"), DATABASE::"Stockkeeping Unit", SKU.GETPOSITION);
        IF NOT OK THEN Location.GET(TransferReqLine."Transfer-from Code");
        OutboundWhseTime:=Location."Outbound Whse. Handling Time";
        Location.GET(TransferReqLine."Location Code");
        InboundWhseTime:=Location."Inbound Whse. Handling Time";
        OK:=TransferRoute.GET(TransferReqLine."Transfer-from Code", TransferReqLine."Location Code");
        IF PlanningResilicency AND NOT OK THEN ReqLine.SetResiliencyError(STRSUBSTNO(Text002, TransferRoute.TABLECAPTION, TransferReqLine."Transfer-from Code", TransferReqLine."Location Code"), DATABASE::"Transfer Route", '');
        IF NOT OK THEN TransferRoute.GET(TransferReqLine."Transfer-from Code", TransferReqLine."Location Code");
        IF ShippingAgentServices.GET(TransferRoute."Shipping Agent Code", TransferRoute."Shipping Agent Service Code")THEN ShippingTime:=ShippingAgentServices."Shipping Time"
        ELSE
            EVALUATE(ShippingTime, '');
        // The calculation will run through the following steps:
        // ShipmentDate <- PlannedShipmentDate <- PlannedReceiptDate <- ReceiptDate
        // Calc Planned Receipt Date (Ending Date) backward from ReceiptDate
        TransferRoute.CalcPlanReceiptDateBackward(TransferReqLine."Ending Date", TransferReqLine."Due Date", InboundWhseTime, TransferReqLine."Location Code", TransferRoute."Shipping Agent Code", TransferRoute."Shipping Agent Service Code");
        // Calc Planned Shipment Date (Starting Date) backward from Planned ReceiptDate (Ending Date)
        TransferRoute.CalcPlanShipmentDateBackward(TransferReqLine."Starting Date", TransferReqLine."Ending Date", ShippingTime, TransferReqLine."Transfer-from Code", TransferRoute."Shipping Agent Code", TransferRoute."Shipping Agent Service Code");
        // Calc Shipment Date backward from Planned Shipment Date (Starting Date)
        TransferRoute.CalcShipmentDateBackward(TransferReqLine."Transfer Shipment Date", TransferReqLine."Starting Date", OutboundWhseTime, TransferReqLine."Transfer-from Code");
        TransferReqLine.UpdateDatetime;
        TransferReqLine.MODIFY;
    end;
    local procedure InsertTempTransferSKU(var TransLine: Record "Transfer Line")
    var
        SKU: Record "Stockkeeping Unit";
    begin
        TempTransferSKU.INIT;
        TempTransferSKU."Item No.":=TransLine."Item No.";
        TempTransferSKU."Variant Code":=TransLine."Variant Code";
        IF TransLine.Quantity > 0 THEN TempTransferSKU."Location Code":=TransLine."Transfer-to Code"
        ELSE
            TempTransferSKU."Location Code":=TransLine."Transfer-from Code";
        IF SKU.GET(TempTransferSKU."Location Code", TempTransferSKU."Item No.", TempTransferSKU."Variant Code")THEN TempTransferSKU."Transfer-from Code":=SKU."Transfer-from Code"
        ELSE
            TempTransferSKU."Transfer-from Code":='';
        IF TempTransferSKU.INSERT THEN;
    end;
    local procedure UpdateTempSKUTransferLevels()
    var
        SKU: Record "Stockkeeping Unit";
    begin
        SKU.COPY(TempSKU);
        TempTransferSKU.RESET;
        IF TempTransferSKU.FIND('-')THEN REPEAT TempSKU.RESET;
                IF TempSKU.GET(TempTransferSKU."Location Code", TempTransferSKU."Item No.", TempTransferSKU."Variant Code")THEN IF TempSKU."Transfer-from Code" = '' THEN BEGIN
                        TempSKU.SETRANGE("Location Code", TempTransferSKU."Transfer-from Code");
                        TempSKU.SETRANGE("Item No.", TempTransferSKU."Item No.");
                        TempSKU.SETRANGE("Variant Code", TempTransferSKU."Variant Code");
                        IF NOT TempSKU.FIND('-')THEN TempTransferSKU."Transfer-Level Code":=-1
                        ELSE
                            TempTransferSKU."Transfer-Level Code":=TempSKU."Transfer-Level Code" - 1;
                        TempSKU.GET(TempTransferSKU."Location Code", TempTransferSKU."Item No.", TempTransferSKU."Variant Code");
                        TempSKU."Transfer-from Code":=TempTransferSKU."Transfer-from Code";
                        TempSKU."Transfer-Level Code":=TempTransferSKU."Transfer-Level Code";
                        TempSKU.MODIFY;
                        TempSKU.UpdateTempSKUTransferLevels(TempSKU, TempSKU, TempSKU."Transfer-from Code");
                    END;
            UNTIL TempTransferSKU.NEXT = 0;
        TempSKU.COPY(SKU);
    end;
    local procedure CancelTransfer(var SupplyInvtProfile: Record "Inventory Profile"; var DemandInvtProfile: Record "Inventory Profile"; DemandExists: Boolean)Cancel: Boolean var
        xSupply2: Record "Inventory Profile";
    begin
        // Used to handle transfers where supply is planned with a higher Transfer Level Code than DemandInvtProfile.
        // If you encounter the demand before the SupplyInvtProfile, the supply must be removed.
        IF NOT DemandExists THEN EXIT(FALSE);
        IF DemandInvtProfile."Source Type" <> DATABASE::"Transfer Line" THEN EXIT(FALSE);
        DemandInvtProfile.TESTFIELD(IsSupply, FALSE);
        xSupply2.COPY(SupplyInvtProfile);
        IF GetTransferSisterProfile(DemandInvtProfile, SupplyInvtProfile)THEN BEGIN
            IF SupplyInvtProfile."Action Message" = SupplyInvtProfile."Action Message"::New THEN SupplyInvtProfile.FIELDERROR("Action Message");
            IF SupplyInvtProfile."Planning Flexibility" = SupplyInvtProfile."Planning Flexibility"::Unlimited THEN BEGIN
                SupplyInvtProfile."Original Quantity":=SupplyInvtProfile.Quantity;
                SupplyInvtProfile."Max. Quantity":=SupplyInvtProfile."Remaining Quantity (Base)";
                SupplyInvtProfile."Quantity (Base)":=SupplyInvtProfile."Min. Quantity";
                SupplyInvtProfile."Remaining Quantity (Base)":=SupplyInvtProfile."Min. Quantity";
                SupplyInvtProfile."Untracked Quantity":=0;
                IF SupplyInvtProfile."Remaining Quantity (Base)" = 0 THEN SupplyInvtProfile."Action Message":=SupplyInvtProfile."Action Message"::Cancel
                ELSE
                    SupplyInvtProfile."Action Message":=SupplyInvtProfile."Action Message"::"Change Qty.";
                SupplyInvtProfile.MODIFY;
                MaintainPlanningLine(SupplyInvtProfile, DemandInvtProfile, PlanningLineStage::Exploded, ScheduleDirection::Backward);
                Track(SupplyInvtProfile, DemandInvtProfile, TRUE, FALSE, SupplyInvtProfile.Binding::" ");
                SupplyInvtProfile.DELETE;
                Cancel:=(SupplyInvtProfile."Action Message" = SupplyInvtProfile."Action Message"::Cancel);
                // IF supply is fully cancelled, demand is deleted, otherwise demand is modified:
                IF Cancel THEN DemandInvtProfile.DELETE
                ELSE
                BEGIN
                    DemandInvtProfile.GET(DemandInvtProfile."Line No."); // Get the updated version
                    DemandInvtProfile."Untracked Quantity"-=(DemandInvtProfile."Original Quantity" - DemandInvtProfile."Quantity (Base)");
                    DemandInvtProfile.MODIFY;
                END;
            END;
        END;
        SupplyInvtProfile.COPY(xSupply2);
    end;
    local procedure PostInvChgReminder(var TempReminderInvtProfile: Record "Inventory Profile" temporary; InvProfile: Record "Inventory Profile"; PostOnlyMinimum: Boolean)
    begin
        // Update information on changes in the Projected Inventory over time
        // Only the quantity that is known for sure should be posted
        OnBeforePostInvChgReminder(TempReminderInvtProfile, InvProfile, PostOnlyMinimum);
        TempReminderInvtProfile:=InvProfile;
        IF PostOnlyMinimum THEN BEGIN
            TempReminderInvtProfile."Remaining Quantity (Base)"-=InvProfile."Untracked Quantity";
            TempReminderInvtProfile."Remaining Quantity (Base)"+=InvProfile."Safety Stock Quantity";
        END;
        IF NOT TempReminderInvtProfile.INSERT THEN TempReminderInvtProfile.MODIFY;
        OnAfterPostInvChgReminder(TempReminderInvtProfile, InvProfile, PostOnlyMinimum);
    end;
    local procedure QtyFromPendingReminders(var TempReminderInvtProfile: Record "Inventory Profile" temporary; AtDate: Date; LatestBucketStartDate: Date)PendingQty: Decimal var
        xReminderInvtProfile: Record "Inventory Profile";
    begin
        // Calculates the sum of queued up adjustments to the projected inventory level
        xReminderInvtProfile.COPY(TempReminderInvtProfile);
        TempReminderInvtProfile.SETRANGE("Due Date", LatestBucketStartDate, AtDate);
        IF TempReminderInvtProfile.FINDSET THEN REPEAT IF TempReminderInvtProfile.IsSupply THEN PendingQty+=TempReminderInvtProfile."Remaining Quantity (Base)"
                ELSE
                    PendingQty-=TempReminderInvtProfile."Remaining Quantity (Base)";
            UNTIL TempReminderInvtProfile.NEXT = 0;
        TempReminderInvtProfile.COPY(xReminderInvtProfile);
    end;
    local procedure MaintainProjectedInventory(var TempReminderInvtProfile: Record "Inventory Profile" temporary; AtDate: Date; var LastProjectedInventory: Decimal; var LatestBucketStartDate: Date; var ROPHasBeenCrossed: Boolean)
    var
        NextBucketEndDate: Date;
        NewProjectedInv: Decimal;
        SupplyIncrementQty: Decimal;
        DemandIncrementQty: Decimal;
        IsHandled: Boolean;
    begin
        // Updates information about projected inventory up until AtDate or until reorder point is crossed.
        // The check is performed within time buckets.
        IsHandled:=FALSE;
        OnBeforeMaintainProjectedInventory(TempReminderInvtProfile, AtDate, LastProjectedInventory, LatestBucketStartDate, ROPHasBeenCrossed, IsHandled);
        IF IsHandled THEN EXIT;
        ROPHasBeenCrossed:=FALSE;
        LatestBucketStartDate:=FindNextBucketStartDate(TempReminderInvtProfile, AtDate, LatestBucketStartDate);
        NextBucketEndDate:=LatestBucketStartDate + BucketSizeInDays - 1;
        WHILE(NextBucketEndDate < AtDate) AND NOT ROPHasBeenCrossed DO BEGIN
            TempReminderInvtProfile.SETFILTER("Due Date", '%1..%2', LatestBucketStartDate, NextBucketEndDate);
            SupplyIncrementQty:=0;
            DemandIncrementQty:=0;
            IF TempReminderInvtProfile.FINDSET THEN REPEAT IF TempReminderInvtProfile.IsSupply THEN BEGIN
                        IF TempReminderInvtProfile."Order Relation" <> TempReminderInvtProfile."Order Relation"::"Safety Stock" THEN SupplyIncrementQty+=TempReminderInvtProfile."Remaining Quantity (Base)";
                    END
                    ELSE
                        DemandIncrementQty-=TempReminderInvtProfile."Remaining Quantity (Base)";
                    TempReminderInvtProfile.DELETE;
                UNTIL TempReminderInvtProfile.NEXT = 0;
            NewProjectedInv:=LastProjectedInventory + SupplyIncrementQty + DemandIncrementQty;
            IF FutureSupplyWithinLeadtime > SupplyIncrementQty THEN FutureSupplyWithinLeadtime-=SupplyIncrementQty
            ELSE
                FutureSupplyWithinLeadtime:=0;
            ROPHasBeenCrossed:=(LastProjectedInventory + SupplyIncrementQty > TempSKU."Reorder Point") AND (NewProjectedInv <= TempSKU."Reorder Point") OR (NewProjectedInv + FutureSupplyWithinLeadtime <= TempSKU."Reorder Point");
            LastProjectedInventory:=NewProjectedInv;
            IF ROPHasBeenCrossed THEN LatestBucketStartDate:=NextBucketEndDate + 1
            ELSE
                LatestBucketStartDate:=FindNextBucketStartDate(TempReminderInvtProfile, AtDate, LatestBucketStartDate);
            NextBucketEndDate:=LatestBucketStartDate + BucketSizeInDays - 1;
        END;
    end;
    local procedure FindNextBucketStartDate(var TempReminderInvtProfile: Record "Inventory Profile" temporary; AtDate: Date; LatestBucketStartDate: Date)NextBucketStartDate: Date var
        NumberOfDaysToNextReminder: Integer;
    begin
        IF AtDate = 0D THEN EXIT(LatestBucketStartDate);
        TempReminderInvtProfile.SETFILTER("Due Date", '%1..%2', LatestBucketStartDate, AtDate);
        IF TempReminderInvtProfile.FINDFIRST THEN AtDate:=TempReminderInvtProfile."Due Date";
        NumberOfDaysToNextReminder:=AtDate - LatestBucketStartDate;
        NextBucketStartDate:=AtDate - (NumberOfDaysToNextReminder MOD BucketSizeInDays);
    end;
    local procedure SetIgnoreOverflow(var SupplyInvtProfile: Record "Inventory Profile")
    begin
        // Apply a minimum quantity to the existing orders to protect the
        // remaining valid surplus from being reduced in the common balancing act
        IF SupplyInvtProfile.FINDSET(TRUE)THEN REPEAT SupplyInvtProfile."Min. Quantity":=SupplyInvtProfile."Remaining Quantity (Base)";
                SupplyInvtProfile.MODIFY;
            UNTIL SupplyInvtProfile.NEXT = 0;
    end;
    local procedure ChkInitialOverflow(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; OverflowLevel: Decimal; InventoryLevel: Decimal; FromDate: Date; ToDate: Date)
    var
        xDemandInvtProfile: Record "Inventory Profile";
        xSupplyInvtProfile: Record "Inventory Profile";
        OverflowQty: Decimal;
        OriginalSupplyQty: Decimal;
        DecreasedSupplyQty: Decimal;
        PrevBucketStartDate: Date;
        PrevBucketEndDate: Date;
        CurrBucketStartDate: Date;
        CurrBucketEndDate: Date;
        NumberOfDaysToNextSupply: Integer;
    begin
        xDemandInvtProfile.COPY(DemandInvtProfile);
        xSupplyInvtProfile.COPY(SupplyInvtProfile);
        SupplyInvtProfile.SETRANGE("Is Exception Order", FALSE);
        IF OverflowLevel > 0 THEN BEGIN
            // Detect if there is overflow in inventory within any time bucket
            // In that case: Decrease superfluous Supply; latest first
            // Apply a minimum quantity to the existing orders to protect the
            // remaining valid surplus from being reduced in the common balancing act
            // Avoid Safety Stock Demand
            DemandInvtProfile.SETRANGE("Order Relation", DemandInvtProfile."Order Relation"::Normal);
            PrevBucketStartDate:=FromDate;
            CurrBucketEndDate:=ToDate;
            WHILE PrevBucketStartDate <= ToDate DO BEGIN
                SupplyInvtProfile.SETRANGE("Due Date", PrevBucketStartDate, ToDate);
                IF SupplyInvtProfile.FINDFIRST THEN BEGIN
                    NumberOfDaysToNextSupply:=SupplyInvtProfile."Due Date" - PrevBucketStartDate;
                    CurrBucketEndDate:=SupplyInvtProfile."Due Date" - (NumberOfDaysToNextSupply MOD BucketSizeInDays) + BucketSizeInDays - 1;
                    CurrBucketStartDate:=CurrBucketEndDate - BucketSizeInDays + 1;
                    PrevBucketEndDate:=CurrBucketStartDate - 1;
                    DemandInvtProfile.SETRANGE("Due Date", PrevBucketStartDate, PrevBucketEndDate);
                    IF DemandInvtProfile.FINDSET THEN REPEAT InventoryLevel-=DemandInvtProfile."Remaining Quantity (Base)";
                        UNTIL DemandInvtProfile.NEXT = 0;
                    // Negative inventory from previous buckets shall not influence
                    // possible overflow in the current time bucket
                    IF InventoryLevel < 0 THEN InventoryLevel:=0;
                    DemandInvtProfile.SETRANGE("Due Date", CurrBucketStartDate, CurrBucketEndDate);
                    IF DemandInvtProfile.FINDSET THEN REPEAT InventoryLevel-=DemandInvtProfile."Remaining Quantity (Base)";
                        UNTIL DemandInvtProfile.NEXT = 0;
                    SupplyInvtProfile.SETRANGE("Due Date", CurrBucketStartDate, CurrBucketEndDate);
                    IF SupplyInvtProfile.FIND('-')THEN BEGIN
                        REPEAT InventoryLevel+=SupplyInvtProfile."Remaining Quantity (Base)";
                        UNTIL SupplyInvtProfile.NEXT = 0;
                        OverflowQty:=InventoryLevel - OverflowLevel;
                        REPEAT IF OverflowQty > 0 THEN BEGIN
                                OriginalSupplyQty:=SupplyInvtProfile."Quantity (Base)";
                                SupplyInvtProfile."Min. Quantity":=0;
                                DecreaseQty(SupplyInvtProfile, OverflowQty, TRUE);
                                // If the supply has not been decreased as planned, try to cancel it.
                                DecreasedSupplyQty:=SupplyInvtProfile."Quantity (Base)";
                                IF(DecreasedSupplyQty > 0) AND (OriginalSupplyQty - DecreasedSupplyQty < OverflowQty) AND (SupplyInvtProfile."Order Priority" < 1000)THEN IF CanDecreaseSupply(SupplyInvtProfile, OverflowQty)THEN DecreaseQty(SupplyInvtProfile, DecreasedSupplyQty, TRUE);
                                IF OriginalSupplyQty <> SupplyInvtProfile."Quantity (Base)" THEN BEGIN
                                    DummyInventoryProfileTrackBuffer."Warning Level":=DummyInventoryProfileTrackBuffer."Warning Level"::Attention;
                                    PlanningTransparency.LogWarning(SupplyInvtProfile."Line No.", ReqLine, DummyInventoryProfileTrackBuffer."Warning Level", STRSUBSTNO(Text010, InventoryLevel, OverflowLevel, CurrBucketEndDate));
                                    OverflowQty-=(OriginalSupplyQty - SupplyInvtProfile."Quantity (Base)");
                                    InventoryLevel-=(OriginalSupplyQty - SupplyInvtProfile."Quantity (Base)");
                                END;
                            END;
                            SupplyInvtProfile."Min. Quantity":=SupplyInvtProfile."Remaining Quantity (Base)";
                            SupplyInvtProfile.MODIFY;
                            IF SupplyInvtProfile."Line No." = xSupplyInvtProfile."Line No." THEN xSupplyInvtProfile:=SupplyInvtProfile;
                        UNTIL(SupplyInvtProfile.NEXT(-1) = 0);
                    END;
                    IF InventoryLevel < 0 THEN InventoryLevel:=0;
                    PrevBucketStartDate:=CurrBucketEndDate + 1;
                END
                ELSE
                    PrevBucketStartDate:=ToDate + 1;
            END;
        END
        ELSE IF OverflowLevel = 0 THEN SetIgnoreOverflow(SupplyInvtProfile);
        DemandInvtProfile.COPY(xDemandInvtProfile);
        SupplyInvtProfile.COPY(xSupplyInvtProfile);
    end;
    local procedure CheckNewOverflow(var SupplyInvtProfile: Record "Inventory Profile"; InventoryLevel: Decimal; QtyToDecreaseOverFlow: Decimal; LastDueDate: Date)
    var
        xSupplyInvtProfile: Record "Inventory Profile";
        OriginalSupplyQty: Decimal;
        QtyToDecrease: Decimal;
    begin
        // the function tries to avoid overflow when a new supply was suggested
        xSupplyInvtProfile.COPY(SupplyInvtProfile);
        SupplyInvtProfile.SETRANGE("Due Date", LastDueDate + 1, PlanToDate);
        SupplyInvtProfile.SETFILTER("Remaining Quantity (Base)", '>0');
        IF SupplyInvtProfile.FINDSET(TRUE)THEN REPEAT IF SupplyInvtProfile."Original Quantity" > 0 THEN InventoryLevel:=InventoryLevel + SupplyInvtProfile."Original Quantity" * SupplyInvtProfile."Qty. per Unit of Measure"
                ELSE
                    InventoryLevel:=InventoryLevel + SupplyInvtProfile."Remaining Quantity (Base)";
                OriginalSupplyQty:=SupplyInvtProfile."Quantity (Base)";
                IF InventoryLevel > OverflowLevel THEN BEGIN
                    SupplyInvtProfile."Min. Quantity":=0;
                    DummyInventoryProfileTrackBuffer."Warning Level":=DummyInventoryProfileTrackBuffer."Warning Level"::Attention;
                    QtyToDecrease:=InventoryLevel - OverflowLevel;
                    IF QtyToDecrease > QtyToDecreaseOverFlow THEN QtyToDecrease:=QtyToDecreaseOverFlow;
                    IF QtyToDecrease > SupplyInvtProfile."Remaining Quantity (Base)" THEN QtyToDecrease:=SupplyInvtProfile."Remaining Quantity (Base)";
                    DecreaseQty(SupplyInvtProfile, QtyToDecrease, TRUE);
                    PlanningTransparency.LogWarning(SupplyInvtProfile."Line No.", ReqLine, DummyInventoryProfileTrackBuffer."Warning Level", STRSUBSTNO(Text010, InventoryLevel, OverflowLevel, SupplyInvtProfile."Due Date"));
                    QtyToDecreaseOverFlow:=QtyToDecreaseOverFlow - (OriginalSupplyQty - SupplyInvtProfile."Quantity (Base)");
                    InventoryLevel:=InventoryLevel - (OriginalSupplyQty - SupplyInvtProfile."Quantity (Base)");
                    SupplyInvtProfile."Min. Quantity":=SupplyInvtProfile."Remaining Quantity (Base)";
                    SupplyInvtProfile.MODIFY;
                END;
            UNTIL(SupplyInvtProfile.NEXT = 0) OR (QtyToDecreaseOverFlow <= 0);
        SupplyInvtProfile.COPY(xSupplyInvtProfile);
    end;
    local procedure CheckScheduleIn(var SupplyInvtProfile: Record "Inventory Profile"; TargetDate: Date; var PossibleDate: Date; LimitedHorizon: Boolean): Boolean begin
        IF SupplyInvtProfile."Planning Flexibility" <> SupplyInvtProfile."Planning Flexibility"::Unlimited THEN EXIT(FALSE);
        IF LimitedHorizon AND NOT AllowScheduleIn(SupplyInvtProfile, TargetDate)THEN PossibleDate:=SupplyInvtProfile."Due Date"
        ELSE
            PossibleDate:=TargetDate;
        EXIT(TargetDate = PossibleDate);
    end;
    local procedure CheckScheduleOut(var SupplyInvtProfile: Record "Inventory Profile"; TargetDate: Date; var PossibleDate: Date; LimitedHorizon: Boolean): Boolean begin
        OnBeforeCheckScheduleOut(SupplyInvtProfile, TempSKU, BucketSize);
        IF SupplyInvtProfile."Planning Flexibility" <> SupplyInvtProfile."Planning Flexibility"::Unlimited THEN EXIT(FALSE);
        IF(TargetDate - SupplyInvtProfile."Due Date") <= DampenersDays THEN PossibleDate:=SupplyInvtProfile."Due Date"
        ELSE IF NOT LimitedHorizon OR (SupplyInvtProfile."Planning Level Code" > 0)THEN PossibleDate:=TargetDate
            ELSE IF AllowScheduleOut(SupplyInvtProfile, TargetDate)THEN PossibleDate:=TargetDate
                ELSE
                BEGIN
                    // Do not reschedule but may be lot accumulation is still an option
                    PossibleDate:=SupplyInvtProfile."Due Date";
                    IF SupplyInvtProfile."Fixed Date" <> 0D THEN EXIT(AllowLotAccumulation(SupplyInvtProfile, TargetDate));
                    EXIT(FALSE);
                END;
        // Limit possible rescheduling in case the supply is already linked up to another demand
        IF(SupplyInvtProfile."Fixed Date" <> 0D) AND (SupplyInvtProfile."Fixed Date" < PossibleDate)THEN BEGIN
            IF NOT AllowLotAccumulation(SupplyInvtProfile, TargetDate)THEN // but reschedule only if lot accumulation is allowed for target date
 EXIT(FALSE);
            PossibleDate:=SupplyInvtProfile."Fixed Date";
        END;
        EXIT(TRUE);
    end;
    local procedure CheckSupplyWithSKU(var InventoryProfile: Record "Inventory Profile"; var SKU: Record "Stockkeeping Unit")
    var
        xInventoryProfile: Record "Inventory Profile";
    begin
        xInventoryProfile.COPY(InventoryProfile);
        IF SKU."Maximum Order Quantity" > 0 THEN IF InventoryProfile.FIND('-')THEN REPEAT IF(SKU."Maximum Order Quantity" > InventoryProfile."Max. Quantity") AND (InventoryProfile."Quantity (Base)" > 0) AND (InventoryProfile."Max. Quantity" = 0)THEN BEGIN
                        InventoryProfile."Max. Quantity":=SKU."Maximum Order Quantity";
                        InventoryProfile.MODIFY;
                    END;
                UNTIL InventoryProfile.NEXT = 0;
        InventoryProfile.COPY(xInventoryProfile);
        IF InventoryProfile.GET(InventoryProfile."Line No.")THEN;
    end;
    local procedure CreateSupplyForward(var SupplyInvtProfile: Record "Inventory Profile"; DemandInvtProfile: Record "Inventory Profile"; AtDate: Date; ProjectedInventory: Decimal; var NewSupplyHasTakenOver: Boolean; CurrDueDate: Date)
    var
        TempSupplyInvtProfile: Record "Inventory Profile" temporary;
        CurrSupplyInvtProfile: Record "Inventory Profile";
        LeadTimeEndDate: Date;
        QtyToOrder: Decimal;
        QtyToOrderThisLine: Decimal;
        SupplyWithinLeadtime: Decimal;
        HasLooped: Boolean;
        CurrSupplyExists: Boolean;
        QtyToDecreaseOverFlow: Decimal;
    begin
        // Save current supply and check if it is real
        CurrSupplyInvtProfile:=SupplyInvtProfile;
        CurrSupplyExists:=SupplyInvtProfile.FIND('=');
        // Initiate new supplyprofile
        InitSupply(TempSupplyInvtProfile, 0, AtDate);
        // Make sure VAR boolean is reset:
        NewSupplyHasTakenOver:=FALSE;
        QtyToOrder:=CalcOrderQty(QtyToOrder, ProjectedInventory, TempSupplyInvtProfile."Line No.");
        // Use new supplyprofile to determine lead-time
        UpdateQty(TempSupplyInvtProfile, QtyToOrder + AdjustReorderQty(QtyToOrder, TempSKU, TempSupplyInvtProfile."Line No.", 0));
        TempSupplyInvtProfile.INSERT;
        ScheduleForward(TempSupplyInvtProfile, DemandInvtProfile, AtDate);
        LeadTimeEndDate:=TempSupplyInvtProfile."Due Date";
        // Find supply within leadtime, returns a qty
        SupplyWithinLeadtime:=SumUpProjectedSupply(SupplyInvtProfile, AtDate, LeadTimeEndDate);
        FutureSupplyWithinLeadtime:=SupplyWithinLeadtime;
        // If found supply + projinvlevel covers ROP then the situation has already been taken care of: roll back and (exit)
        IF SupplyWithinLeadtime + ProjectedInventory > TempSKU."Reorder Point" THEN BEGIN
            // Delete obsolete Planning Line
            MaintainPlanningLine(TempSupplyInvtProfile, DemandInvtProfile, PlanningLineStage::Obsolete, ScheduleDirection::Backward);
            PlanningTransparency.CleanLog(TempSupplyInvtProfile."Line No.");
            EXIT;
        END;
        // If found supply only covers ROP partialy, then we need to adjust quantity.
        IF TempSKU."Reordering Policy" = TempSKU."Reordering Policy"::"Fixed Reorder Qty." THEN IF SupplyWithinLeadtime > 0 THEN BEGIN
                QtyToOrder-=SupplyWithinLeadtime;
                IF QtyToOrder < TempSKU."Reorder Quantity" THEN QtyToOrder:=TempSKU."Reorder Quantity";
                PlanningTransparency.ModifyLogEntry(TempSupplyInvtProfile."Line No.", 0, DATABASE::Item, TempSKU."Item No.", -SupplyWithinLeadtime, SurplusType::ReorderPoint);
            END;
        // If Max: Deduct found supply in order to stay below max inventory and adjust transparency log
        IF TempSKU."Reordering Policy" = TempSKU."Reordering Policy"::"Maximum Qty." THEN IF SupplyWithinLeadtime <> 0 THEN BEGIN
                QtyToOrder-=SupplyWithinLeadtime;
                PlanningTransparency.ModifyLogEntry(TempSupplyInvtProfile."Line No.", 0, DATABASE::Item, TempSKU."Item No.", -SupplyWithinLeadtime, SurplusType::MaxInventory);
            END;
        LeadTimeEndDate:=AtDate;
        WHILE QtyToOrder > 0 DO BEGIN
            // In case of max order the new supply could be split in several new supplies:
            IF HasLooped THEN BEGIN
                InitSupply(TempSupplyInvtProfile, 0, AtDate);
                CASE TempSKU."Reordering Policy" OF TempSKU."Reordering Policy"::"Maximum Qty.": SurplusType:=SurplusType::MaxInventory;
                TempSKU."Reordering Policy"::"Fixed Reorder Qty.": SurplusType:=SurplusType::FixedOrderQty;
                END;
                PlanningTransparency.LogSurplus(TempSupplyInvtProfile."Line No.", 0, 0, '', QtyToOrder, SurplusType);
                QtyToOrderThisLine:=QtyToOrder + AdjustReorderQty(QtyToOrder, TempSKU, TempSupplyInvtProfile."Line No.", 0);
                UpdateQty(TempSupplyInvtProfile, QtyToOrderThisLine);
                TempSupplyInvtProfile.INSERT;
                ScheduleForward(TempSupplyInvtProfile, DemandInvtProfile, AtDate);
            END
            ELSE
            BEGIN
                QtyToOrderThisLine:=QtyToOrder + AdjustReorderQty(QtyToOrder, TempSKU, TempSupplyInvtProfile."Line No.", 0);
                IF QtyToOrderThisLine <> TempSupplyInvtProfile."Remaining Quantity (Base)" THEN BEGIN
                    UpdateQty(TempSupplyInvtProfile, QtyToOrderThisLine);
                    ScheduleForward(TempSupplyInvtProfile, DemandInvtProfile, AtDate);
                END;
                HasLooped:=TRUE;
            END;
            // The supply is inserted into the overall supply dataset
            SupplyInvtProfile:=TempSupplyInvtProfile;
            TempSupplyInvtProfile.DELETE;
            SupplyInvtProfile."Min. Quantity":=SupplyInvtProfile."Remaining Quantity (Base)";
            SupplyInvtProfile."Max. Quantity":=TempSKU."Maximum Order Quantity";
            SupplyInvtProfile."Fixed Date":=SupplyInvtProfile."Due Date";
            SupplyInvtProfile."Order Priority":=1000; // Make sure to give last priority if supply exists on the same date
            SupplyInvtProfile."Attribute Priority":=1000;
            SupplyInvtProfile.INSERT;
            // Planning Transparency
            PlanningTransparency.LogSurplus(SupplyInvtProfile."Line No.", 0, 0, '', SupplyInvtProfile."Untracked Quantity", SurplusType::ReorderPoint);
            IF SupplyInvtProfile."Due Date" < CurrDueDate THEN BEGIN
                CurrSupplyInvtProfile:=SupplyInvtProfile;
                CurrDueDate:=SupplyInvtProfile."Due Date";
                NewSupplyHasTakenOver:=TRUE END;
            IF LeadTimeEndDate < SupplyInvtProfile."Due Date" THEN LeadTimeEndDate:=SupplyInvtProfile."Due Date";
            IF(NOT CurrSupplyExists) OR (SupplyInvtProfile."Due Date" < CurrSupplyInvtProfile."Due Date")THEN BEGIN
                CurrSupplyInvtProfile:=SupplyInvtProfile;
                CurrSupplyExists:=TRUE;
                NewSupplyHasTakenOver:=CurrSupplyInvtProfile."Due Date" <= CurrDueDate;
            END;
            QtyToOrder-=SupplyInvtProfile."Remaining Quantity (Base)";
            FutureSupplyWithinLeadtime+=SupplyInvtProfile."Remaining Quantity (Base)";
            QtyToDecreaseOverFlow+=SupplyInvtProfile."Quantity (Base)";
        END;
        IF HasLooped AND (OverflowLevel > 0)THEN // the new supply might cause overflow in inventory since
 // it wasn't considered when Overflow was calculated
            CheckNewOverflow(SupplyInvtProfile, ProjectedInventory + QtyToDecreaseOverFlow, QtyToDecreaseOverFlow, LeadTimeEndDate);
        SupplyInvtProfile:=CurrSupplyInvtProfile;
    end;
    local procedure AllowScheduleIn(SupplyInvtProfile: Record "Inventory Profile"; TargetDate: Date)CanReschedule: Boolean begin
        CanReschedule:=CALCDATE(TempSKU."Rescheduling Period", TargetDate) >= SupplyInvtProfile."Due Date";
    end;
    local procedure AllowScheduleOut(SupplyInvtProfile: Record "Inventory Profile"; TargetDate: Date)CanReschedule: Boolean begin
        CanReschedule:=CALCDATE(TempSKU."Rescheduling Period", SupplyInvtProfile."Due Date") >= TargetDate;
    end;
    local procedure AllowLotAccumulation(SupplyInvtProfile: Record "Inventory Profile"; DemandDueDate: Date)AccumulationOK: Boolean begin
        AccumulationOK:=CALCDATE(TempSKU."Lot Accumulation Period", SupplyInvtProfile."Due Date") >= DemandDueDate;
    end;
    local procedure ShallSupplyBeClosed(SupplyInventoryProfile: Record "Inventory Profile"; DemandDueDate: Date; IsReorderPointPlanning: Boolean): Boolean var
        CloseSupply: Boolean;
    begin
        IF SupplyInventoryProfile."Is Exception Order" THEN BEGIN
            IF TempSKU."Reordering Policy" = TempSKU."Reordering Policy"::"Lot-for-Lot" THEN // supply within Lot Accumulation Period will be summed up with Exception order
 CloseSupply:=NOT AllowLotAccumulation(SupplyInventoryProfile, DemandDueDate)
            ELSE
                // only demand in the same day as Exception will be summed up
                CloseSupply:=SupplyInventoryProfile."Due Date" <> DemandDueDate;
        END
        ELSE
            CloseSupply:=IsReorderPointPlanning;
        EXIT(CloseSupply);
    end;
    local procedure NextLineNo(): Integer begin
        LineNo+=1;
        EXIT(LineNo);
    end;
    local procedure Reschedule(var SupplyInvtProfile: Record "Inventory Profile"; TargetDate: Date; TargetTime: Time)
    begin
        SupplyInvtProfile.TESTFIELD("Planning Flexibility", SupplyInvtProfile."Planning Flexibility"::Unlimited);
        IF(TargetDate <> SupplyInvtProfile."Due Date") AND (SupplyInvtProfile."Action Message" <> SupplyInvtProfile."Action Message"::New)THEN BEGIN
            IF SupplyInvtProfile."Original Due Date" = 0D THEN SupplyInvtProfile."Original Due Date":=SupplyInvtProfile."Due Date";
            IF SupplyInvtProfile."Original Quantity" = 0 THEN SupplyInvtProfile."Action Message":=SupplyInvtProfile."Action Message"::Reschedule
            ELSE
                SupplyInvtProfile."Action Message":=SupplyInvtProfile."Action Message"::"Resched. & Chg. Qty.";
        END;
        SupplyInvtProfile."Due Date":=TargetDate;
        IF(SupplyInvtProfile."Due Time" = 0T) OR (SupplyInvtProfile."Due Time" > TargetTime)THEN SupplyInvtProfile."Due Time":=TargetTime;
        SupplyInvtProfile.MODIFY;
    end;
    local procedure InitSupply(var SupplyInvtProfile: Record "Inventory Profile"; OrderQty: Decimal; DueDate: Date)
    var
        Item: Record "Item";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        SupplyInvtProfile.INIT;
        SupplyInvtProfile."Line No.":=NextLineNo;
        SupplyInvtProfile."Item No.":=TempSKU."Item No.";
        SupplyInvtProfile."Variant Code":=TempSKU."Variant Code";
        SupplyInvtProfile."Location Code":=TempSKU."Location Code";
        SupplyInvtProfile."Action Message":=SupplyInvtProfile."Action Message"::New;
        UpdateQty(SupplyInvtProfile, OrderQty);
        SupplyInvtProfile."Due Date":=DueDate;
        SupplyInvtProfile.IsSupply:=TRUE;
        Item.GET(TempSKU."Item No.");
        SupplyInvtProfile."Unit of Measure Code":=Item."Base Unit of Measure";
        SupplyInvtProfile."Qty. per Unit of Measure":=1;
        CASE TempSKU."Replenishment System" OF TempSKU."Replenishment System"::Purchase: BEGIN
            SupplyInvtProfile."Source Type":=DATABASE::"Purchase Line";
            SupplyInvtProfile."Unit of Measure Code":=Item."Purch. Unit of Measure";
            IF SupplyInvtProfile."Unit of Measure Code" <> Item."Base Unit of Measure" THEN BEGIN
                ItemUnitOfMeasure.GET(TempSKU."Item No.", Item."Purch. Unit of Measure");
                SupplyInvtProfile."Qty. per Unit of Measure":=ItemUnitOfMeasure."Qty. per Unit of Measure";
            END;
        END;
        TempSKU."Replenishment System"::"Prod. Order": SupplyInvtProfile."Source Type":=DATABASE::"Prod. Order Line";
        TempSKU."Replenishment System"::Assembly: SupplyInvtProfile."Source Type":=DATABASE::"Assembly Header";
        TempSKU."Replenishment System"::Transfer: SupplyInvtProfile."Source Type":=DATABASE::"Transfer Line";
        END;
    end;
    local procedure UpdateQty(var InvProfile: Record "Inventory Profile"; Qty: Decimal)
    begin
        InvProfile."Untracked Quantity":=Qty;
        InvProfile."Quantity (Base)":=InvProfile."Untracked Quantity";
        InvProfile."Remaining Quantity (Base)":=InvProfile."Quantity (Base)";
    end;
    local procedure TransferAttributes(var ToInvProfile: Record "Inventory Profile"; var FromInvProfile: Record "Inventory Profile")
    begin
        IF SpecificLotTracking THEN ToInvProfile."Lot No.":=FromInvProfile."Lot No.";
        IF SpecificSNTracking THEN ToInvProfile."Serial No.":=FromInvProfile."Serial No.";
        IF TempSKU."Replenishment System" = TempSKU."Replenishment System"::"Prod. Order" THEN IF FromInvProfile."Planning Level Code" > 0 THEN BEGIN
                ToInvProfile.Binding:=ToInvProfile.Binding::"Order-to-Order";
                ToInvProfile."Planning Level Code":=FromInvProfile."Planning Level Code";
                ToInvProfile."Due Time":=FromInvProfile."Due Time";
                ToInvProfile."Bin Code":=FromInvProfile."Bin Code";
            END;
        IF FromInvProfile.Binding = FromInvProfile.Binding::"Order-to-Order" THEN BEGIN
            ToInvProfile.Binding:=ToInvProfile.Binding::"Order-to-Order";
            ToInvProfile."Primary Order Status":=FromInvProfile."Primary Order Status";
            ToInvProfile."Primary Order No.":=FromInvProfile."Primary Order No.";
            ToInvProfile."Primary Order Line":=FromInvProfile."Primary Order Line";
        END;
        ToInvProfile."MPS Order":=FromInvProfile."MPS Order";
        IF ToInvProfile.TrackingExists THEN ToInvProfile."Planning Flexibility":=ToInvProfile."Planning Flexibility"::None;
        OnAfterTransferAttributes(ToInvProfile, FromInvProfile, TempSKU, SpecificLotTracking, SpecificSNTracking);
    end;
    local procedure AllocateSafetystock(var SupplyInvtProfile: Record "Inventory Profile"; QtyToAllocate: Decimal; AtDate: Date)
    var
        MinQtyToCoverSafetyStock: Decimal;
    begin
        IF QtyToAllocate > SupplyInvtProfile."Safety Stock Quantity" THEN BEGIN
            SupplyInvtProfile."Safety Stock Quantity":=QtyToAllocate;
            MinQtyToCoverSafetyStock:=SupplyInvtProfile."Remaining Quantity (Base)" - SupplyInvtProfile."Untracked Quantity" + SupplyInvtProfile."Safety Stock Quantity";
            IF SupplyInvtProfile."Min. Quantity" < MinQtyToCoverSafetyStock THEN SupplyInvtProfile."Min. Quantity":=MinQtyToCoverSafetyStock;
            IF SupplyInvtProfile."Min. Quantity" > SupplyInvtProfile."Remaining Quantity (Base)" THEN ERROR(Text001, SupplyInvtProfile.FIELDCAPTION("Safety Stock Quantity"));
            IF(SupplyInvtProfile."Fixed Date" = 0D) OR (SupplyInvtProfile."Fixed Date" > AtDate)THEN SupplyInvtProfile."Fixed Date":=AtDate;
            SupplyInvtProfile.MODIFY;
        END;
    end;
    local procedure SumUpProjectedSupply(var SupplyInvtProfile: Record "Inventory Profile"; FromDate: Date; ToDate: Date)ProjectedQty: Decimal var
        xSupplyInvtProfile: Record "Inventory Profile";
    begin
        // Sums up the contribution to the projected inventory
        xSupplyInvtProfile.COPY(SupplyInvtProfile);
        SupplyInvtProfile.SETRANGE("Due Date", FromDate, ToDate);
        IF SupplyInvtProfile.FINDSET THEN REPEAT IF(SupplyInvtProfile.Binding <> SupplyInvtProfile.Binding::"Order-to-Order") AND (SupplyInvtProfile."Order Relation" <> SupplyInvtProfile."Order Relation"::"Safety Stock")THEN ProjectedQty+=SupplyInvtProfile."Remaining Quantity (Base)";
            UNTIL SupplyInvtProfile.NEXT = 0;
        SupplyInvtProfile.COPY(xSupplyInvtProfile);
    end;
    local procedure SumUpAvailableSupply(var SupplyInvtProfile: Record "Inventory Profile"; FromDate: Date; ToDate: Date)AvailableQty: Decimal var
        xSupplyInvtProfile: Record "Inventory Profile";
    begin
        // Sums up the contribution to the available inventory
        xSupplyInvtProfile.COPY(SupplyInvtProfile);
        SupplyInvtProfile.SETRANGE("Due Date", FromDate, ToDate);
        IF SupplyInvtProfile.FINDSET THEN REPEAT AvailableQty+=SupplyInvtProfile."Untracked Quantity";
            UNTIL SupplyInvtProfile.NEXT = 0;
        SupplyInvtProfile.COPY(xSupplyInvtProfile);
    end;
    local procedure SetPriority(var InvProfile: Record "Inventory Profile"; IsReorderPointPlanning: Boolean; ToDate: Date)
    begin
        IF InvProfile.IsSupply THEN BEGIN
            IF InvProfile."Due Date" > ToDate THEN InvProfile."Planning Flexibility":=InvProfile."Planning Flexibility"::None;
            IF IsReorderPointPlanning AND (InvProfile.Binding <> InvProfile.Binding::"Order-to-Order") AND (InvProfile."Planning Flexibility" <> InvProfile."Planning Flexibility"::None)THEN InvProfile."Planning Flexibility":=InvProfile."Planning Flexibility"::"Reduce Only";
            CASE InvProfile."Source Type" OF DATABASE::"Item Ledger Entry": InvProfile."Order Priority":=100;
            DATABASE::"Sales Line": CASE InvProfile."Source Order Status" OF // Quote,Order,Invoice,Credit Memo,Blanket Order,Return Order
 5: InvProfile."Order Priority":=200;
                // Return Order
                1: InvProfile."Order Priority":=200;
                // Negative Sales Order
                END;
            DATABASE::"Job Planning Line": InvProfile."Order Priority":=230;
            DATABASE::"Transfer Line", DATABASE::"Requisition Line", DATABASE::"Planning Component": InvProfile."Order Priority":=300;
            DATABASE::"Assembly Header": InvProfile."Order Priority":=320;
            DATABASE::"Prod. Order Line": CASE InvProfile."Source Order Status" OF // Simulated,Planned,Firm Planned,Released,Finished
 3: InvProfile."Order Priority":=400;
                // Released
                2: InvProfile."Order Priority":=410;
                // Firm Planned
                1: InvProfile."Order Priority":=420;
                // Planned
                END;
            DATABASE::"Purchase Line": InvProfile."Order Priority":=500;
            DATABASE::"Prod. Order Component": CASE InvProfile."Source Order Status" OF // Simulated,Planned,Firm Planned,Released,Finished
 3: InvProfile."Order Priority":=600;
                // Released
                2: InvProfile."Order Priority":=610;
                // Firm Planned
                1: InvProfile."Order Priority":=620;
                // Planned
                END;
            END;
        END
        ELSE
            // Demand
            CASE InvProfile."Source Type" OF DATABASE::"Item Ledger Entry": InvProfile."Order Priority":=100;
            DATABASE::"Purchase Line": InvProfile."Order Priority":=200;
            DATABASE::"Sales Line": CASE InvProfile."Source Order Status" OF // Quote,Order,Invoice,Credit Memo,Blanket Order,Return Order
 1: InvProfile."Order Priority":=300;
                // Order
                4: InvProfile."Order Priority":=700;
                // Blanket Order
                5: InvProfile."Order Priority":=300;
                // Negative Return Order
                END;
            DATABASE::"Service Line": InvProfile."Order Priority":=400;
            DATABASE::"Job Planning Line": InvProfile."Order Priority":=450;
            DATABASE::"Assembly Line": InvProfile."Order Priority":=470;
            DATABASE::"Prod. Order Component": CASE InvProfile."Source Order Status" OF // Simulated,Planned,Firm Planned,Released,Finished
 3: InvProfile."Order Priority":=500;
                // Released
                2: InvProfile."Order Priority":=510;
                // Firm Planned
                1: InvProfile."Order Priority":=520;
                // Planned
                END;
            DATABASE::"Transfer Line", DATABASE::"Requisition Line", DATABASE::"Planning Component": InvProfile."Order Priority":=600;
            DATABASE::"Production Forecast Entry": InvProfile."Order Priority":=800;
            END;
        OnAfterSetOrderPriority(InvProfile);
        InvProfile.TESTFIELD(InvProfile."Order Priority");
        // Inflexible supply must be handled before all other supply and is therefore grouped
        // together with inventory in group 100:
        IF InvProfile.IsSupply AND (InvProfile."Source Type" <> DATABASE::"Item Ledger Entry")THEN IF InvProfile."Planning Flexibility" <> InvProfile."Planning Flexibility"::Unlimited THEN InvProfile."Order Priority":=100 + (InvProfile."Order Priority" / 10);
        IF InvProfile."Planning Flexibility" = InvProfile."Planning Flexibility"::Unlimited THEN IF InvProfile.ActiveInWarehouse THEN InvProfile."Order Priority"-=1;
        SetAttributePriority(InvProfile);
        InvProfile.MODIFY;
    end;
    local procedure SetAttributePriority(var InvProfile: Record "Inventory Profile")
    var
        HandleLot: Boolean;
        HandleSN: Boolean;
    begin
        HandleSN:=(InvProfile."Serial No." <> '') AND SpecificSNTracking;
        HandleLot:=(InvProfile."Lot No." <> '') AND SpecificLotTracking;
        IF HandleSN THEN BEGIN
            IF HandleLot THEN IF InvProfile.Binding = InvProfile.Binding::"Order-to-Order" THEN InvProfile."Attribute Priority":=1
                ELSE
                    InvProfile."Attribute Priority":=4
            ELSE IF InvProfile.Binding = InvProfile.Binding::"Order-to-Order" THEN InvProfile."Attribute Priority":=2
                ELSE
                    InvProfile."Attribute Priority":=5;
        END
        ELSE
        BEGIN
            IF HandleLot THEN IF InvProfile.Binding = InvProfile.Binding::"Order-to-Order" THEN InvProfile."Attribute Priority":=3
                ELSE
                    InvProfile."Attribute Priority":=6
            ELSE IF InvProfile.Binding = InvProfile.Binding::"Order-to-Order" THEN InvProfile."Attribute Priority":=7
                ELSE
                    InvProfile."Attribute Priority":=8;
        END;
    end;
    local procedure UpdatePriorities(var InvProfile: Record "Inventory Profile"; IsReorderPointPlanning: Boolean; ToDate: Date)
    var
        xInvProfile: Record "Inventory Profile";
    begin
        xInvProfile.COPY(InvProfile);
        InvProfile.SETCURRENTKEY("Line No.");
        IF InvProfile.FINDSET(TRUE)THEN REPEAT SetPriority(InvProfile, IsReorderPointPlanning, ToDate);
            UNTIL InvProfile.NEXT = 0;
        InvProfile.COPY(xInvProfile);
    end;
    local procedure InsertSafetyStockDemands(var DemandInvtProfile: Record "Inventory Profile"; PlanningStartDate: Date)
    var
        xDemandInvtProfile: Record "Inventory Profile";
        TempSafetyStockInvtProfile: Record "Inventory Profile" temporary;
        OrderRelation: Option Normal, "Safety Stock", "Reorder Point";
    begin
        IF TempSKU."Safety Stock Quantity" = 0 THEN EXIT;
        xDemandInvtProfile.COPY(DemandInvtProfile);
        DemandInvtProfile.SETCURRENTKEY("Item No.", "Variant Code", "Location Code", "Due Date", "Attribute Priority", "Order Priority");
        DemandInvtProfile.SETFILTER("Due Date", '%1..', PlanningStartDate);
        IF DemandInvtProfile.FINDSET THEN REPEAT IF TempSafetyStockInvtProfile."Due Date" <> DemandInvtProfile."Due Date" THEN CreateDemand(TempSafetyStockInvtProfile, TempSKU, TempSKU."Safety Stock Quantity", DemandInvtProfile."Due Date", OrderRelation::"Safety Stock");
            UNTIL DemandInvtProfile.NEXT = 0;
        DemandInvtProfile.SETRANGE("Due Date", PlanningStartDate);
        IF DemandInvtProfile.ISEMPTY THEN CreateDemand(TempSafetyStockInvtProfile, TempSKU, TempSKU."Safety Stock Quantity", PlanningStartDate, OrderRelation::"Safety Stock");
        IF TempSafetyStockInvtProfile.FINDSET(TRUE)THEN REPEAT DemandInvtProfile:=TempSafetyStockInvtProfile;
                DemandInvtProfile."Order Priority":=1000;
                DemandInvtProfile.INSERT;
            UNTIL TempSafetyStockInvtProfile.NEXT = 0;
        DemandInvtProfile.COPY(xDemandInvtProfile);
        OnAfterInsertSafetyStockDemands(DemandInvtProfile, xDemandInvtProfile, TempSafetyStockInvtProfile, TempSKU, PlanningStartDate, PlanToDate);
    end;
    local procedure ScheduleAllOutChangesSequence(var SupplyInvtProfile: Record "Inventory Profile"; NewDate: Date): Boolean var
        xSupplyInvtProfile: Record "Inventory Profile";
        TempRescheduledSupplyInvtProfile: Record "Inventory Profile" temporary;
        TryRescheduleSupply: Boolean;
        HasLooped: Boolean;
        Continue: Boolean;
        NumberofSupplies: Integer;
    begin
        xSupplyInvtProfile.COPY(SupplyInvtProfile);
        IF(SupplyInvtProfile."Due Date" = 0D) OR (SupplyInvtProfile."Planning Flexibility" <> SupplyInvtProfile."Planning Flexibility"::Unlimited)THEN EXIT(FALSE);
        IF NOT AllowScheduleOut(SupplyInvtProfile, NewDate)THEN EXIT(FALSE);
        Continue:=TRUE;
        TryRescheduleSupply:=TRUE;
        WHILE Continue DO BEGIN
            NumberofSupplies+=1;
            TempRescheduledSupplyInvtProfile:=SupplyInvtProfile;
            TempRescheduledSupplyInvtProfile."Line No.":=-TempRescheduledSupplyInvtProfile."Line No."; // Use negative Line No. to shift sequence
            TempRescheduledSupplyInvtProfile.INSERT;
            IF TryRescheduleSupply THEN BEGIN
                Reschedule(TempRescheduledSupplyInvtProfile, NewDate, 0T);
                Continue:=TempRescheduledSupplyInvtProfile."Due Date" <> SupplyInvtProfile."Due Date";
            END;
            IF Continue THEN IF SupplyInvtProfile.NEXT <> 0 THEN BEGIN
                    Continue:=SupplyInvtProfile."Due Date" <= NewDate;
                    TryRescheduleSupply:=(SupplyInvtProfile."Planning Flexibility" = SupplyInvtProfile."Planning Flexibility"::Unlimited) AND (SupplyInvtProfile."Fixed Date" = 0D);
                END
                ELSE
                    Continue:=FALSE;
        END;
        // If there is only one supply before the demand we roll back
        IF NumberofSupplies = 1 THEN BEGIN
            SupplyInvtProfile.COPY(xSupplyInvtProfile);
            EXIT(FALSE);
        END;
        TempRescheduledSupplyInvtProfile.SETCURRENTKEY("Item No.", "Variant Code", "Location Code", "Due Date", "Attribute Priority", "Order Priority");
        // If we have resheduled we replace the original supply records with the resceduled ones,
        // we re-write the primary key to make sure that the supplies are handled in the right order.
        IF TempRescheduledSupplyInvtProfile.FINDSET THEN BEGIN
            REPEAT SupplyInvtProfile."Line No.":=-TempRescheduledSupplyInvtProfile."Line No.";
                SupplyInvtProfile.DELETE;
                SupplyInvtProfile:=TempRescheduledSupplyInvtProfile;
                SupplyInvtProfile."Line No.":=NextLineNo;
                SupplyInvtProfile.INSERT;
                IF NOT HasLooped THEN BEGIN
                    xSupplyInvtProfile:=SupplyInvtProfile; // The first supply is bookmarked
                    HasLooped:=TRUE;
                END;
            UNTIL TempRescheduledSupplyInvtProfile.NEXT = 0;
            SupplyInvtProfile:=xSupplyInvtProfile;
        END;
        EXIT(TRUE);
    end;
    local procedure PrepareOrderToOrderLink(var InventoryProfile: Record "Inventory Profile")
    begin
        // Prepare new demand for order-to-order planning
        IF InventoryProfile.FINDSET(TRUE)THEN REPEAT IF NOT InventoryProfile.IsSupply THEN IF NOT(InventoryProfile."Source Type" = DATABASE::"Production Forecast Entry")THEN IF NOT((InventoryProfile."Source Type" = DATABASE::"Sales Line") AND (InventoryProfile."Source Order Status" = 4))THEN // Blanket Order
 IF(TempSKU."Reordering Policy" = TempSKU."Reordering Policy"::Order) OR (InventoryProfile."Planning Level Code" <> 0)THEN BEGIN
                                IF InventoryProfile."Source Type" = DATABASE::"Planning Component" THEN BEGIN
                                    // Primary Order references have already been set on Component Lines
                                    InventoryProfile.Binding:=InventoryProfile.Binding::"Order-to-Order";
                                END
                                ELSE
                                BEGIN
                                    InventoryProfile.Binding:=InventoryProfile.Binding::"Order-to-Order";
                                    InventoryProfile."Primary Order Type":=InventoryProfile."Source Type";
                                    InventoryProfile."Primary Order Status":=InventoryProfile."Source Order Status";
                                    InventoryProfile."Primary Order No.":=InventoryProfile."Source ID";
                                    IF InventoryProfile."Source Type" <> DATABASE::"Prod. Order Component" THEN InventoryProfile."Primary Order Line":=InventoryProfile."Source Ref. No.";
                                END;
                                InventoryProfile.MODIFY;
                            END;
            UNTIL InventoryProfile.NEXT = 0;
    end;
    local procedure SetAcceptAction(ItemNo: Code[20])
    var
        ReqLine: Record "Requisition Line";
        PurchHeader: Record "Purchase Header";
        ProdOrder: Record "Production Order";
        TransHeader: Record "Transfer Header";
        AsmHeader: Record "Assembly Header";
        ReqWkshTempl: Record "Req. Wksh. Template";
        AcceptActionMsg: Boolean;
    begin
        ReqWkshTempl.GET(CurrTemplateName);
        IF ReqWkshTempl.Type <> ReqWkshTempl.Type::Planning THEN EXIT;
        ReqLine.SETCURRENTKEY(ReqLine."Worksheet Template Name", ReqLine."Journal Batch Name", ReqLine.Type, ReqLine."No.");
        ReqLine.SETRANGE(ReqLine."Worksheet Template Name", CurrTemplateName);
        ReqLine.SETRANGE(ReqLine."Journal Batch Name", CurrWorksheetName);
        ReqLine.SETRANGE(ReqLine.Type, ReqLine.Type::Item);
        ReqLine.SETRANGE(ReqLine."No.", ItemNo);
        DummyInventoryProfileTrackBuffer."Warning Level":=DummyInventoryProfileTrackBuffer."Warning Level"::Attention;
        IF ReqLine.FINDSET(TRUE)THEN REPEAT AcceptActionMsg:=ReqLine."Starting Date" >= WORKDATE;
                IF NOT AcceptActionMsg THEN PlanningTransparency.LogWarning(0, ReqLine, DummyInventoryProfileTrackBuffer."Warning Level", STRSUBSTNO(Text008, DummyInventoryProfileTrackBuffer."Warning Level", ReqLine.FIELDCAPTION(ReqLine."Starting Date"), ReqLine."Starting Date", WORKDATE));
                IF ReqLine."Action Message" <> ReqLine."Action Message"::New THEN CASE ReqLine."Ref. Order Type" OF ReqLine."Ref. Order Type"::Purchase: IF(PurchHeader.GET(PurchHeader."Document Type"::Order, ReqLine."Ref. Order No.") AND (PurchHeader.Status = PurchHeader.Status::Released))THEN BEGIN
                            AcceptActionMsg:=FALSE;
                            PlanningTransparency.LogWarning(0, ReqLine, DummyInventoryProfileTrackBuffer."Warning Level", STRSUBSTNO(Text009, DummyInventoryProfileTrackBuffer."Warning Level", PurchHeader.FIELDCAPTION(Status), ReqLine."Ref. Order Type", ReqLine."Ref. Order No.", PurchHeader.Status));
                        END;
                    ReqLine."Ref. Order Type"::"Prod. Order": IF ReqLine."Ref. Order Status" = ProdOrder.Status::Released.AsInteger()THEN BEGIN
                            AcceptActionMsg:=FALSE;
                            PlanningTransparency.LogWarning(0, ReqLine, DummyInventoryProfileTrackBuffer."Warning Level", STRSUBSTNO(Text009, DummyInventoryProfileTrackBuffer."Warning Level", ProdOrder.FIELDCAPTION(Status), ReqLine."Ref. Order Type", ReqLine."Ref. Order No.", ReqLine."Ref. Order Status"));
                        END;
                    ReqLine."Ref. Order Type"::Assembly: IF AsmHeader.GET(ReqLine."Ref. Order Status", ReqLine."Ref. Order No.") AND (AsmHeader.Status = AsmHeader.Status::Released)THEN BEGIN
                            AcceptActionMsg:=FALSE;
                            PlanningTransparency.LogWarning(0, ReqLine, DummyInventoryProfileTrackBuffer."Warning Level", STRSUBSTNO(Text009, DummyInventoryProfileTrackBuffer."Warning Level", AsmHeader.FIELDCAPTION(Status), ReqLine."Ref. Order Type", ReqLine."Ref. Order No.", AsmHeader.Status));
                        END;
                    ReqLine."Ref. Order Type"::Transfer: IF(TransHeader.GET(ReqLine."Ref. Order No.") AND (TransHeader.Status = TransHeader.Status::Released))THEN BEGIN
                            AcceptActionMsg:=FALSE;
                            PlanningTransparency.LogWarning(0, ReqLine, DummyInventoryProfileTrackBuffer."Warning Level", STRSUBSTNO(Text009, DummyInventoryProfileTrackBuffer."Warning Level", TransHeader.FIELDCAPTION(Status), ReqLine."Ref. Order Type", ReqLine."Ref. Order No.", TransHeader.Status));
                        END;
                    END;
                IF AcceptActionMsg THEN AcceptActionMsg:=PlanningTransparency.ReqLineWarningLevel(ReqLine) = 0;
                IF NOT AcceptActionMsg THEN BEGIN
                    ReqLine."Accept Action Message":=FALSE;
                    ReqLine.MODIFY;
                END;
            UNTIL ReqLine.NEXT = 0;
    end;
    procedure GetRouting(var ReqLine: Record "Requisition Line")
    var
        PlanRoutingLine: Record "Planning Routing Line";
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
        ProdOrderLine: Record "Prod. Order Line";
        VersionMgt: Codeunit "VersionManagement";
    begin
        IF ReqLine.Quantity <= 0 THEN EXIT;
        IF(ReqLine."Action Message" = ReqLine."Action Message"::New) OR (ReqLine."Ref. Order Type" = ReqLine."Ref. Order Type"::Purchase)THEN BEGIN
            IF ReqLine."Routing No." <> '' THEN ReqLine.VALIDATE(ReqLine."Routing Version Code", VersionMgt.GetRtngVersion(ReqLine."Routing No.", ReqLine."Due Date", TRUE));
            CLEAR(PlngLnMgt);
            IF PlanningResilicency THEN PlngLnMgt.SetResiliencyOn(ReqLine."Worksheet Template Name", ReqLine."Journal Batch Name", ReqLine."No.");
        END
        ELSE IF ReqLine."Ref. Order Type" = ReqLine."Ref. Order Type"::"Prod. Order" THEN BEGIN
                ProdOrderLine.GET(ReqLine."Ref. Order Status", ReqLine."Ref. Order No.", ReqLine."Ref. Line No.");
                ProdOrderRoutingLine.SETRANGE(Status, ProdOrderLine.Status);
                ProdOrderRoutingLine.SETRANGE("Prod. Order No.", ProdOrderLine."Prod. Order No.");
                ProdOrderRoutingLine.SETRANGE("Routing Reference No.", ProdOrderLine."Routing Reference No.");
                ProdOrderRoutingLine.SETRANGE("Routing No.", ProdOrderLine."Routing No.");
                DisableRelations;
                IF ProdOrderRoutingLine.FIND('-')THEN REPEAT PlanRoutingLine.INIT;
                        PlanRoutingLine."Worksheet Template Name":=ReqLine."Worksheet Template Name";
                        PlanRoutingLine."Worksheet Batch Name":=ReqLine."Journal Batch Name";
                        PlanRoutingLine."Worksheet Line No.":=ReqLine."Line No.";
                        PlanRoutingLine.TransferFromProdOrderRouting(ProdOrderRoutingLine);
                        PlanRoutingLine.INSERT;
                    UNTIL ProdOrderRoutingLine.NEXT = 0;
            END;
    end;
    procedure GetComponents(var ReqLine: Record "Requisition Line")
    var
        PlanComponent: Record "Planning Component";
        ProdOrderComp: Record "Prod. Order Component";
        AsmLine: Record "Assembly Line";
        VersionMgt: Codeunit "VersionManagement";
    begin
        ReqLine.BlockDynamicTracking(TRUE);
        CLEAR(PlngLnMgt);
        IF PlanningResilicency THEN PlngLnMgt.SetResiliencyOn(ReqLine."Worksheet Template Name", ReqLine."Journal Batch Name", ReqLine."No.");
        PlngLnMgt.BlockDynamicTracking(TRUE);
        IF ReqLine."Action Message" = ReqLine."Action Message"::New THEN BEGIN
            IF ReqLine."Production BOM No." <> '' THEN ReqLine.VALIDATE(ReqLine."Production BOM Version Code", VersionMgt.GetBOMVersion(ReqLine."Production BOM No.", ReqLine."Due Date", TRUE));
        END
        ELSE
            CASE ReqLine."Ref. Order Type" OF ReqLine."Ref. Order Type"::"Prod. Order": BEGIN
                ProdOrderComp.SETRANGE(Status, ReqLine."Ref. Order Status");
                ProdOrderComp.SETRANGE("Prod. Order No.", ReqLine."Ref. Order No.");
                ProdOrderComp.SETRANGE("Prod. Order Line No.", ReqLine."Ref. Line No.");
                IF ProdOrderComp.FIND('-')THEN REPEAT PlanComponent.INIT;
                        PlanComponent."Worksheet Template Name":=ReqLine."Worksheet Template Name";
                        PlanComponent."Worksheet Batch Name":=ReqLine."Journal Batch Name";
                        PlanComponent."Worksheet Line No.":=ReqLine."Line No.";
                        PlanComponent."Planning Line Origin":=ReqLine."Planning Line Origin";
                        PlanComponent.TransferFromComponent(ProdOrderComp);
                        PlanComponent.INSERT;
                        TempPlanningCompList:=PlanComponent;
                        IF NOT TempPlanningCompList.INSERT THEN TempPlanningCompList.MODIFY;
                    UNTIL ProdOrderComp.NEXT = 0;
            END;
            ReqLine."Ref. Order Type"::Assembly: BEGIN
                AsmLine.SETRANGE("Document Type", AsmLine."Document Type"::Order);
                AsmLine.SETRANGE("Document No.", ReqLine."Ref. Order No.");
                AsmLine.SETRANGE(Type, AsmLine.Type::Item);
                IF AsmLine.FIND('-')THEN REPEAT PlanComponent.INIT;
                        PlanComponent."Worksheet Template Name":=ReqLine."Worksheet Template Name";
                        PlanComponent."Worksheet Batch Name":=ReqLine."Journal Batch Name";
                        PlanComponent."Worksheet Line No.":=ReqLine."Line No.";
                        PlanComponent."Planning Line Origin":=ReqLine."Planning Line Origin";
                        PlanComponent.TransferFromAsmLine(AsmLine);
                        PlanComponent.INSERT;
                        TempPlanningCompList:=PlanComponent;
                        IF NOT TempPlanningCompList.INSERT THEN TempPlanningCompList.MODIFY;
                    UNTIL AsmLine.NEXT = 0;
            END;
            END;
    end;
    procedure Recalculate(var ReqLine: Record "Requisition Line"; Direction: Option Forward, Backward; RefreshRouting: Boolean)
    begin
        PlngLnMgt.Calculate(ReqLine, Direction, RefreshRouting, (ReqLine."Action Message" = ReqLine."Action Message"::New) AND (ReqLine."Ref. Order Type" IN[ReqLine."Ref. Order Type"::"Prod. Order", ReqLine."Ref. Order Type"::Assembly]), -1);
        IF ReqLine."Action Message" = ReqLine."Action Message"::New THEN PlngLnMgt.GetPlanningCompList(TempPlanningCompList);
    end;
    procedure GetPlanningCompList(var PlanningCompList: Record "Planning Component" temporary)
    begin
        IF TempPlanningCompList.FIND('-')THEN REPEAT PlanningCompList:=TempPlanningCompList;
                IF NOT PlanningCompList.INSERT THEN PlanningCompList.MODIFY;
                TempPlanningCompList.DELETE;
            UNTIL TempPlanningCompList.NEXT = 0;
    end;
    procedure SetParm(Forecast: Code[10]; ExclBefore: Date; WorksheetType: Option Requisition, Planning)
    begin
        CurrForecast:=Forecast;
        ExcludeForecastBefore:=ExclBefore;
        UseParm:=TRUE;
        CurrWorksheetType:=WorksheetType;
    end;
    procedure SetResiliencyOn()
    begin
        PlanningResilicency:=TRUE;
    end;
    procedure GetResiliencyError(var PlanningErrorLog: Record "Planning Error Log"): Boolean begin
        IF ReqLine.GetResiliencyError(PlanningErrorLog)THEN EXIT(TRUE);
        EXIT(PlngLnMgt.GetResiliencyError(PlanningErrorLog));
    end;
    local procedure CloseTracking(ReservEntry: Record "Reservation Entry"; var SupplyInventoryProfile: Record "Inventory Profile"; ToDate: Date): Boolean var
        xSupplyInventoryProfile: Record "Inventory Profile";
        ReservationEngineMgt: Codeunit "Reservation Engine Mgt.";
        Closed: Boolean;
    begin
        IF ReservEntry."Reservation Status" <> ReservEntry."Reservation Status"::Tracking THEN EXIT(FALSE);
        xSupplyInventoryProfile.COPY(SupplyInventoryProfile);
        Closed:=FALSE;
        IF(ReservEntry."Expected Receipt Date" <= ToDate) AND (ReservEntry."Shipment Date" > ToDate)THEN BEGIN
            // tracking exists with demand in future
            SupplyInventoryProfile.SETCURRENTKEY("Source Type", "Source Order Status", "Source ID", "Source Batch Name", "Source Ref. No.", "Source Prod. Order Line", IsSupply, "Due Date");
            SupplyInventoryProfile.SETRANGE("Source Type", ReservEntry."Source Type");
            SupplyInventoryProfile.SETRANGE("Source Order Status", ReservEntry."Source Subtype");
            SupplyInventoryProfile.SETRANGE("Source ID", ReservEntry."Source ID");
            SupplyInventoryProfile.SETRANGE("Source Batch Name", ReservEntry."Source Batch Name");
            SupplyInventoryProfile.SETRANGE("Source Ref. No.", ReservEntry."Source Ref. No.");
            SupplyInventoryProfile.SETRANGE("Source Prod. Order Line", ReservEntry."Source Prod. Order Line");
            SupplyInventoryProfile.SETRANGE("Due Date", 0D, ToDate);
            IF NOT SupplyInventoryProfile.ISEMPTY THEN BEGIN
                // demand is either deleted as well or will get Surplus status
                ReservationEngineMgt.CloseReservEntry(ReservEntry, FALSE, FALSE);
                Closed:=TRUE;
            END;
        END;
        SupplyInventoryProfile.COPY(xSupplyInventoryProfile);
        EXIT(Closed);
    end;
    local procedure FrozenZoneTrack(FromInventoryProfile: Record "Inventory Profile"; ToInventoryProfile: Record "Inventory Profile")
    begin
        IF FromInventoryProfile.TrackingExists THEN Track(FromInventoryProfile, ToInventoryProfile, TRUE, FALSE, FromInventoryProfile.Binding::" ");
        IF ToInventoryProfile.TrackingExists THEN BEGIN
            ToInventoryProfile."Untracked Quantity":=FromInventoryProfile."Untracked Quantity";
            ToInventoryProfile."Quantity (Base)":=FromInventoryProfile."Untracked Quantity";
            ToInventoryProfile."Original Quantity":=0;
            Track(ToInventoryProfile, FromInventoryProfile, TRUE, FALSE, ToInventoryProfile.Binding::" ");
        END;
    end;
    local procedure ExceedROPinException(RespectPlanningParm: Boolean): Boolean begin
        IF NOT RespectPlanningParm THEN EXIT(FALSE);
        EXIT(TempSKU."Reordering Policy" = TempSKU."Reordering Policy"::"Fixed Reorder Qty.");
    end;
    local procedure CreateSupplyForInitialSafetyStockWarning(var SupplyInventoryProfile: Record "Inventory Profile"; ProjectedInventory: Decimal; var LastProjectedInventory: Decimal; var LastAvailableInventory: Decimal; PlanningStartDate: Date; RespectPlanningParm: Boolean; IsReorderPointPlanning: Boolean)
    var
        OrderQty: Decimal;
        ReorderQty: Decimal;
    begin
        OrderQty:=TempSKU."Safety Stock Quantity" - ProjectedInventory;
        IF ExceedROPinException(RespectPlanningParm)THEN OrderQty:=TempSKU."Reorder Point" - ProjectedInventory;
        ReorderQty:=OrderQty;
        REPEAT InitSupply(SupplyInventoryProfile, ReorderQty, PlanningStartDate);
            IF RespectPlanningParm THEN BEGIN
                IF IsReorderPointPlanning THEN ReorderQty:=CalcOrderQty(ReorderQty, ProjectedInventory, SupplyInventoryProfile."Line No.");
                ReorderQty+=AdjustReorderQty(ReorderQty, TempSKU, SupplyInventoryProfile."Line No.", SupplyInventoryProfile."Min. Quantity");
                SupplyInventoryProfile."Max. Quantity":=TempSKU."Maximum Order Quantity";
                UpdateQty(SupplyInventoryProfile, ReorderQty);
                SupplyInventoryProfile."Min. Quantity":=SupplyInventoryProfile."Quantity (Base)";
            END;
            SupplyInventoryProfile."Fixed Date":=SupplyInventoryProfile."Due Date";
            SupplyInventoryProfile."Order Relation":=SupplyInventoryProfile."Order Relation"::"Safety Stock";
            SupplyInventoryProfile."Is Exception Order":=TRUE;
            SupplyInventoryProfile.INSERT;
            DummyInventoryProfileTrackBuffer."Warning Level":=DummyInventoryProfileTrackBuffer."Warning Level"::Exception;
            PlanningTransparency.LogWarning(SupplyInventoryProfile."Line No.", ReqLine, DummyInventoryProfileTrackBuffer."Warning Level", STRSUBSTNO(Text007, DummyInventoryProfileTrackBuffer."Warning Level", TempSKU.FIELDCAPTION("Safety Stock Quantity"), TempSKU."Safety Stock Quantity", PlanningStartDate));
            LastProjectedInventory+=SupplyInventoryProfile."Remaining Quantity (Base)";
            ProjectedInventory+=SupplyInventoryProfile."Remaining Quantity (Base)";
            LastAvailableInventory+=SupplyInventoryProfile."Untracked Quantity";
            OrderQty-=ReorderQty;
            IF ExceedROPinException(RespectPlanningParm) AND (OrderQty = 0)THEN OrderQty:=ExceedROPqty;
            ReorderQty:=OrderQty;
        UNTIL OrderQty <= 0; // Create supplies until Safety Stock is met or Reorder point is exceeded
    end;
    local procedure IsTrkgForSpecialOrderOrDropShpt(ReservEntry: Record "Reservation Entry"): Boolean var
        SalesLine: Record "Sales Line";
        PurchLine: Record "Purchase Line";
    begin
        CASE ReservEntry."Source Type" OF DATABASE::"Sales Line": IF SalesLine.GET(ReservEntry."Source Subtype", ReservEntry."Source ID", ReservEntry."Source Ref. No.")THEN EXIT(SalesLine."Special Order" OR SalesLine."Drop Shipment");
        DATABASE::"Purchase Line": IF PurchLine.GET(ReservEntry."Source Subtype", ReservEntry."Source ID", ReservEntry."Source Ref. No.")THEN EXIT(PurchLine."Special Order" OR PurchLine."Drop Shipment");
        END;
        EXIT(FALSE);
    end;
    local procedure CheckSupplyRemQtyAndUntrackQty(var InventoryProfile: Record "Inventory Profile")
    var
        RemQty: Decimal;
    begin
        IF InventoryProfile."Source Type" = DATABASE::"Item Ledger Entry" THEN EXIT;
        IF InventoryProfile."Remaining Quantity (Base)" >= TempSKU."Maximum Order Quantity" THEN BEGIN
            RemQty:=InventoryProfile."Remaining Quantity (Base)";
            InventoryProfile."Remaining Quantity (Base)":=TempSKU."Maximum Order Quantity";
            IF NOT(InventoryProfile."Action Message" IN[InventoryProfile."Action Message"::New, InventoryProfile."Action Message"::Reschedule])THEN InventoryProfile."Original Quantity":=InventoryProfile."Quantity (Base)";
        END;
        IF InventoryProfile."Untracked Quantity" >= TempSKU."Maximum Order Quantity" THEN InventoryProfile."Untracked Quantity":=InventoryProfile."Untracked Quantity" - RemQty + InventoryProfile."Remaining Quantity (Base)";
    end;
    local procedure CheckItemInventoryExists(var InventoryProfile: Record "Inventory Profile")ItemInventoryExists: Boolean begin
        InventoryProfile.SETRANGE(InventoryProfile."Source Type", DATABASE::"Item Ledger Entry");
        InventoryProfile.SETFILTER(InventoryProfile.Binding, '<>%1', InventoryProfile.Binding::"Order-to-Order");
        ItemInventoryExists:=NOT InventoryProfile.ISEMPTY;
        InventoryProfile.SETRANGE(InventoryProfile."Source Type");
        InventoryProfile.SETRANGE(InventoryProfile.Binding);
    end;
    local procedure ApplyUntrackedQuantityToItemInventory(SupplyExists: Boolean; ItemInventoryExists: Boolean): Boolean begin
        IF SupplyExists THEN EXIT(FALSE);
        EXIT(ItemInventoryExists);
    end;
    local procedure UpdateAppliedItemEntry(var ReservEntry: Record "Reservation Entry")
    begin
        TempItemTrkgEntry.SetSourceFilter(ReservEntry."Source Type", ReservEntry."Source Subtype", ReservEntry."Source ID", ReservEntry."Source Ref. No.", TRUE);
        IF ReservEntry."Lot No." <> '' THEN TempItemTrkgEntry.SETRANGE(TempItemTrkgEntry."Lot No.", ReservEntry."Lot No.");
        IF ReservEntry."Serial No." <> '' THEN TempItemTrkgEntry.SETRANGE(TempItemTrkgEntry."Serial No.", ReservEntry."Serial No.");
        IF TempItemTrkgEntry.FINDFIRST THEN BEGIN
            ReservEntry."Appl.-from Item Entry":=TempItemTrkgEntry."Appl.-from Item Entry";
            ReservEntry."Appl.-to Item Entry":=TempItemTrkgEntry."Appl.-to Item Entry";
        END;
    end;
    local procedure CheckSupplyAndTrack(InventoryProfileFromDemand: Record "Inventory Profile"; InventoryProfileFromSupply: Record "Inventory Profile")
    begin
        IF InventoryProfileFromSupply."Source Type" = DATABASE::"Item Ledger Entry" THEN Track(InventoryProfileFromDemand, InventoryProfileFromSupply, FALSE, FALSE, InventoryProfileFromSupply.Binding)
        ELSE
            Track(InventoryProfileFromDemand, InventoryProfileFromSupply, FALSE, FALSE, InventoryProfileFromDemand.Binding);
    end;
    local procedure CheckPlanSKU(SKU: Record "Stockkeeping Unit"; DemandExists: Boolean; SupplyExists: Boolean; IsReorderPointPlanning: Boolean): Boolean begin
        IF(CurrWorksheetType = CurrWorksheetType::Requisition) AND (SKU."Replenishment System" IN[SKU."Replenishment System"::"Prod. Order", SKU."Replenishment System"::Assembly])THEN EXIT(FALSE);
        IF DemandExists OR SupplyExists OR IsReorderPointPlanning THEN EXIT(TRUE);
        EXIT(FALSE);
    end;
    local procedure PrepareDemand(var InventoryProfile: Record "Inventory Profile"; IsReorderPointPlanning: Boolean; ToDate: Date)
    begin
        // Transfer attributes
        IF(TempSKU."Reordering Policy" = TempSKU."Reordering Policy"::Order) OR (TempSKU."Manufacturing Policy" = TempSKU."Manufacturing Policy"::"Make-to-Order")THEN PrepareOrderToOrderLink(InventoryProfile);
        UpdatePriorities(InventoryProfile, IsReorderPointPlanning, ToDate);
    end;
    local procedure DemandMatchedSupply(var FromInventoryProfile: Record "Inventory Profile"; var ToInventoryProfile: Record "Inventory Profile"; SKU: Record "Stockkeeping Unit"): Boolean var
        xFromInventoryProfile: Record "Inventory Profile";
        xToInventoryProfile: Record "Inventory Profile";
        UntrackedQty: Decimal;
    begin
        xToInventoryProfile.COPYFILTERS(FromInventoryProfile);
        xFromInventoryProfile.COPYFILTERS(ToInventoryProfile);
        FromInventoryProfile.SETRANGE(FromInventoryProfile."Attribute Priority", 1, 7);
        IF FromInventoryProfile.FINDSET THEN BEGIN
            REPEAT ToInventoryProfile.SETRANGE(Binding, FromInventoryProfile.Binding);
                ToInventoryProfile.SETRANGE("Primary Order Status", FromInventoryProfile."Primary Order Status");
                ToInventoryProfile.SETRANGE("Primary Order No.", FromInventoryProfile."Primary Order No.");
                ToInventoryProfile.SETRANGE("Primary Order Line", FromInventoryProfile."Primary Order Line");
                ToInventoryProfile.SetTrackingFilter(FromInventoryProfile);
                IF ToInventoryProfile.FINDSET THEN REPEAT UntrackedQty+=ToInventoryProfile."Untracked Quantity";
                    UNTIL ToInventoryProfile.NEXT = 0;
                UntrackedQty-=FromInventoryProfile."Untracked Quantity";
            UNTIL FromInventoryProfile.NEXT = 0;
            IF(UntrackedQty = 0) AND (SKU."Reordering Policy" = SKU."Reordering Policy"::"Lot-for-Lot")THEN BEGIN
                FromInventoryProfile.SETRANGE(FromInventoryProfile."Attribute Priority", 8);
                FromInventoryProfile.CALCSUMS(FromInventoryProfile."Untracked Quantity");
                IF FromInventoryProfile."Untracked Quantity" = 0 THEN BEGIN
                    FromInventoryProfile.COPYFILTERS(xToInventoryProfile);
                    ToInventoryProfile.COPYFILTERS(xFromInventoryProfile);
                    EXIT(TRUE);
                END;
            END;
        END;
        FromInventoryProfile.COPYFILTERS(xToInventoryProfile);
        ToInventoryProfile.COPYFILTERS(xFromInventoryProfile);
        EXIT(FALSE);
    end;
    local procedure ReservedForProdComponent(ReservationEntry: Record "Reservation Entry"): Boolean begin
        IF NOT ReservationEntry.Positive THEN EXIT(ReservationEntry."Source Type" = DATABASE::"Prod. Order Component");
        IF ReservationEntry.GET(ReservationEntry."Entry No.", FALSE)THEN EXIT(ReservationEntry."Source Type" = DATABASE::"Prod. Order Component");
    end;
    local procedure ShouldInsertTrackingEntry(FromTrkgReservEntry: Record "Reservation Entry"): Boolean var
        InsertedReservEntry: Record "Reservation Entry";
    begin
        InsertedReservEntry.SETRANGE(InsertedReservEntry."Source ID", FromTrkgReservEntry."Source ID");
        InsertedReservEntry.SETRANGE(InsertedReservEntry."Source Ref. No.", FromTrkgReservEntry."Source Ref. No.");
        InsertedReservEntry.SETRANGE(InsertedReservEntry."Source Type", FromTrkgReservEntry."Source Type");
        InsertedReservEntry.SETRANGE(InsertedReservEntry."Source Subtype", FromTrkgReservEntry."Source Subtype");
        InsertedReservEntry.SETRANGE(InsertedReservEntry."Source Batch Name", FromTrkgReservEntry."Source Batch Name");
        InsertedReservEntry.SETRANGE(InsertedReservEntry."Source Prod. Order Line", FromTrkgReservEntry."Source Prod. Order Line");
        InsertedReservEntry.SETRANGE(InsertedReservEntry."Reservation Status", FromTrkgReservEntry."Reservation Status");
        EXIT(InsertedReservEntry.ISEMPTY);
    end;
    local procedure CloseInventoryProfile(var ClosedInvtProfile: Record "Inventory Profile"; var OpenInvtProfile: Record "Inventory Profile"; ActionMessage: Option " ", New, "Change Qty.", Reschedule, "Resched.& Chg. Qty.", Cancel)
    var
        PlanningStageToMaintain: Option " ", "Line Created", "Routing Created", Exploded, Obsolete;
    begin
        OpenInvtProfile."Untracked Quantity"-=ClosedInvtProfile."Untracked Quantity";
        OpenInvtProfile.MODIFY;
        IF OpenInvtProfile.Binding = OpenInvtProfile.Binding::"Order-to-Order" THEN PlanningStageToMaintain:=PlanningStageToMaintain::Exploded
        ELSE
            PlanningStageToMaintain:=PlanningStageToMaintain::"Line Created";
        IF ActionMessage <> ActionMessage::" " THEN IF OpenInvtProfile.IsSupply THEN MaintainPlanningLine(OpenInvtProfile, ClosedInvtProfile, PlanningStageToMaintain, ScheduleDirection::Backward)
            ELSE
                MaintainPlanningLine(ClosedInvtProfile, ClosedInvtProfile, PlanningStageToMaintain, ScheduleDirection::Backward);
        Track(ClosedInvtProfile, OpenInvtProfile, FALSE, FALSE, OpenInvtProfile.Binding);
        IF ClosedInvtProfile.Binding = ClosedInvtProfile.Binding::"Order-to-Order" THEN ClosedInvtProfile."Remaining Quantity (Base)"-=ClosedInvtProfile."Untracked Quantity";
        ClosedInvtProfile."Untracked Quantity":=0;
        IF ClosedInvtProfile."Remaining Quantity (Base)" = 0 THEN ClosedInvtProfile.DELETE
        ELSE
            ClosedInvtProfile.MODIFY;
    end;
    local procedure CloseDemand(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile")
    begin
        CloseInventoryProfile(DemandInvtProfile, SupplyInvtProfile, SupplyInvtProfile."Action Message".AsInteger());
    end;
    local procedure CloseSupply(var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"): Boolean begin
        CloseInventoryProfile(SupplyInvtProfile, DemandInvtProfile, SupplyInvtProfile."Action Message".AsInteger());
        EXIT(SupplyInvtProfile.NEXT <> 0);
    end;
    local procedure QtyPickedForSourceDocument(TrkgReservEntry: Record "Reservation Entry"): Decimal var
        WhseEntry: Record "Warehouse Entry";
    begin
        WhseEntry.SETRANGE("Item No.", TrkgReservEntry."Item No.");
        WhseEntry.SetSourceFilter(TrkgReservEntry."Source Type", TrkgReservEntry."Source Subtype", TrkgReservEntry."Source ID", TrkgReservEntry."Source Ref. No.", FALSE);
        WhseEntry.SETRANGE("Lot No.", TrkgReservEntry."Lot No.");
        WhseEntry.SETRANGE("Serial No.", TrkgReservEntry."Serial No.");
        WhseEntry.SETFILTER("Qty. (Base)", '<0');
        WhseEntry.CALCSUMS("Qty. (Base)");
        EXIT(WhseEntry."Qty. (Base)");
    end;
    local procedure CreateTempSKUForComponentsLocation(var Item: Record "Item")
    var
        SKU: Record "Stockkeeping Unit";
    begin
        IF ManufacturingSetup."Components at Location" = '' THEN EXIT;
        SKU.SETRANGE("Item No.", Item."No.");
        SKU.SETRANGE("Location Code", ManufacturingSetup."Components at Location");
        Item.COPYFILTER("Variant Filter", SKU."Variant Code");
        IF SKU.ISEMPTY THEN CreateTempSKUForLocation(Item."No.", ManufacturingSetup."Components at Location");
    end;
    local procedure ForecastInitDemand(var InventoryProfile: Record "Inventory Profile"; ProductionForecastEntry: Record "Production Forecast Entry"; ItemNo: Code[20]; LocationCode: Code[10]; TotalForecastQty: Decimal)
    begin
        InventoryProfile.INIT;
        InventoryProfile."Line No.":=NextLineNo;
        InventoryProfile."Source Type":=DATABASE::"Production Forecast Entry";
        InventoryProfile."Planning Flexibility":=InventoryProfile."Planning Flexibility"::None;
        InventoryProfile."Qty. per Unit of Measure":=1;
        InventoryProfile."MPS Order":=TRUE;
        InventoryProfile."Source ID":=ProductionForecastEntry."Production Forecast Name";
        InventoryProfile."Item No.":=ItemNo;
        IF ManufacturingSetup."Use Forecast on Locations" THEN InventoryProfile."Location Code":=ProductionForecastEntry."Location Code"
        ELSE
            InventoryProfile."Location Code":=LocationCode;
        InventoryProfile."Remaining Quantity (Base)":=TotalForecastQty;
        InventoryProfile."Untracked Quantity":=TotalForecastQty;
    end;
    local procedure SetPurchase(var PurchaseLine: Record "Purchase Line"; var InventoryProfile: Record "Inventory Profile")
    begin
        ReqLine."Ref. Order Type":=ReqLine."Ref. Order Type"::Purchase;
        ReqLine."Ref. Order No.":=InventoryProfile."Source ID";
        ReqLine."Ref. Line No.":=InventoryProfile."Source Ref. No.";
        PurchaseLine.GET(PurchaseLine."Document Type"::Order, ReqLine."Ref. Order No.", ReqLine."Ref. Line No.");
        ReqLine.TransferFromPurchaseLine(PurchaseLine);
    end;
    local procedure SetProdOrder(var ProdOrderLine: Record "Prod. Order Line"; var InventoryProfile: Record "Inventory Profile")
    begin
        ReqLine."Ref. Order Type":=ReqLine."Ref. Order Type"::"Prod. Order";
        ReqLine."Ref. Order Status":=InventoryProfile."Source Order Status";
        ReqLine."Ref. Order No.":=InventoryProfile."Source ID";
        ReqLine."Ref. Line No.":=InventoryProfile."Source Prod. Order Line";
        ProdOrderLine.GET(ReqLine."Ref. Order Status", ReqLine."Ref. Order No.", ReqLine."Ref. Line No.");
        ReqLine.TransferFromProdOrderLine(ProdOrderLine);
    end;
    local procedure SetAssembly(var AsmHeader: Record "Assembly Header"; var InventoryProfile: Record "Inventory Profile")
    begin
        ReqLine."Ref. Order Type":=ReqLine."Ref. Order Type"::Assembly;
        ReqLine."Ref. Order No.":=InventoryProfile."Source ID";
        ReqLine."Ref. Line No.":=0;
        AsmHeader.GET(AsmHeader."Document Type"::Order, ReqLine."Ref. Order No.");
        ReqLine.TransferFromAsmHeader(AsmHeader);
    end;
    local procedure SetTransfer(var TransLine: Record "Transfer Line"; var InventoryProfile: Record "Inventory Profile")
    begin
        ReqLine."Ref. Order Type":=ReqLine."Ref. Order Type"::Transfer;
        ReqLine."Ref. Order Status":=0;
        // A Transfer Order has no status
        ReqLine."Ref. Order No.":=InventoryProfile."Source ID";
        ReqLine."Ref. Line No.":=InventoryProfile."Source Ref. No.";
        TransLine.GET(ReqLine."Ref. Order No.", ReqLine."Ref. Line No.");
        ReqLine.TransferFromTransLine(TransLine);
    end;
    procedure SetReqWorksheetAllLoc(LocationCodeP: Code[10]; NewStatusP: Boolean)
    var
        ReplenishmentSubLocations: Record "Replenishment Sub Locations";
    begin
        //Omar+
        IF(LocationCodeP = '') OR NOT NewStatusP THEN BEGIN
            ReqWorksheetAllLoc:=FALSE;
            EXIT;
        END;
        ReqWorksheetLocationCode:=LocationCodeP;
        ReqWorksheetAllLoc:=NewStatusP;
        ReqWorksheetLocFilter:='';
        ReplenishmentSubLocations.RESET;
        ReplenishmentSubLocations.SETRANGE("Main Location Code", LocationCodeP);
        ReplenishmentSubLocations.SETFILTER("Location Code", '<>%1', '');
        IF ReplenishmentSubLocations.FINDSET THEN BEGIN
            REPEAT ReqWorksheetLocFilter:=ReqWorksheetLocFilter + '|' + ReplenishmentSubLocations."Location Code";
            UNTIL ReplenishmentSubLocations.NEXT = 0;
            ReqWorksheetLocFilter:=LocationCodeP + ReqWorksheetLocFilter;
        END
        ELSE
        BEGIN
            ReqWorksheetAllLoc:=FALSE;
            ReqWorksheetLocationCode:='';
        END;
    //Omar-
    end;
    local procedure FromLotAccumulationPeriodStartDate(LotAccumulationPeriodStartDate: Date; DemandDueDate: Date): Boolean begin
        IF LotAccumulationPeriodStartDate > 0D THEN EXIT(CALCDATE(TempSKU."Lot Accumulation Period", LotAccumulationPeriodStartDate) >= DemandDueDate);
    end;
    [IntegrationEvent(false, false)]
    local procedure OnAfterCalculatePlanFromWorksheet(var Item: Record "Item")
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnAfterTransToChildInvProfile(var ReservEntry: Record "Reservation Entry"; var ChildInvtProfile: Record "Inventory Profile")
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnAfterDemandToInvProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; var ReservEntry: Record "Reservation Entry"; var NextLineNo: Integer)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnAfterSupplyToInvProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; var ToDate: Date; var ReservEntry: Record "Reservation Entry"; var NextLineNo: Integer)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforeSupplyToInvProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; var ToDate: Date; var ReservEntry: Record "Reservation Entry"; var NextLineNo: Integer)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnAfterSetOrderPriority(var InventoryProfile: Record "Inventory Profile")
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnAfterShouldDeleteReservEntry(ReservationEntry: Record "Reservation Entry"; ToDate: Date; var DeleteCondition: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnAfterTransferAttributes(var ToInventoryProfile: Record "Inventory Profile"; var FromInventoryProfile: Record "Inventory Profile"; var TempSKU: Record "Stockkeeping Unit" temporary; SpecificLotTracking: Boolean; SpecificSNTracking: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforeAdjustPlanLine(var RequisitionLine: Record "Requisition Line"; var SupplyInventoryProfile: Record "Inventory Profile")
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforeBlanketOrderConsumpFind(var BlanketSalesLine: Record "Sales Line")
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforeCheckScheduleOut(var InventoryProfile: Record "Inventory Profile"; var TempStockkeepingUnit: Record "Stockkeeping Unit" temporary; BucketSize: DateFormula)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforeCommonBalancing(var TempSKU: Record "Stockkeeping Unit" temporary; var DemandInvtProfile: Record "Inventory Profile"; var SupplyInvtProfile: Record "Inventory Profile"; PlanningStartDate: Date; ToDate: Date)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforeDemandInvtProfileInsert(var InventoryProfile: Record "Inventory Profile"; StockkeepingUnit: Record "Stockkeeping Unit")
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforeDemandToInvProfile(var InventoryProfile: Record "Inventory Profile"; var Item: Record "Item"; var IsHandled: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforeMatchAttributesDemandApplicationLoop(var SupplyInventoryProfile: Record "Inventory Profile"; var DemandInventoryProfile: Record "Inventory Profile"; var SupplyExists: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnEndMatchAttributesDemandApplicationLoop(var SupplyInventoryProfile: Record "Inventory Profile"; var DemandInventoryProfile: Record "Inventory Profile"; var SupplyExists: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnStartOfMatchAttributesDemandApplicationLoop(var SupplyInventoryProfile: Record "Inventory Profile"; var DemandInventoryProfile: Record "Inventory Profile"; var SupplyExists: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforePrePlanDateApplicationLoop(var SupplyInventoryProfile: Record "Inventory Profile"; var DemandInventoryProfile: Record "Inventory Profile"; var SupplyExists: Boolean; var DemandExists: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnStartOfPrePlanDateApplicationLoop(var SupplyInventoryProfile: Record "Inventory Profile"; var DemandInventoryProfile: Record "Inventory Profile"; var SupplyExists: Boolean; var DemandExists: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforePrePlanDateDemandProc(var SupplyInventoryProfile: Record "Inventory Profile"; var DemandInventoryProfile: Record "Inventory Profile"; var SupplyExists: Boolean; var DemandExists: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforePrePlanDateSupplyProc(var SupplyInventoryProfile: Record "Inventory Profile"; var DemandInventoryProfile: Record "Inventory Profile"; var SupplyExists: Boolean; var DemandExists: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnAfterPrePlanDateSupplyProc(var SupplyInventoryProfile: Record "Inventory Profile"; var DemandInventoryProfile: Record "Inventory Profile"; var SupplyExists: Boolean; var DemandExists: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforePlanStepSettingOnStartOver(var SupplyInventoryProfile: Record "Inventory Profile"; var DemandInventoryProfile: Record "Inventory Profile"; var SupplyExists: Boolean; var DemandExists: Boolean; var NextState: Option; var IsHandled: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforeCalculatePlanFromWorksheet(var Item: Record "Item"; ManufacturingSetup2: Record "Manufacturing Setup"; TemplateName: Code[10]; WorksheetName: Code[10]; OrderDate: Date; ToDate: Date; MRPPlanning: Boolean; RespectPlanningParm: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnAfterInsertSafetyStockDemands(var DemandInvtProfile: Record "Inventory Profile"; xDemandInvtProfile: Record "Inventory Profile"; var TempSafetyStockInvtProfile: Record "Inventory Profile" temporary; var TempStockkeepingUnit: Record "Stockkeeping Unit" temporary; var PlanningStartDate: Date; var PlanToDate: Date)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnFindCombinationAfterAssignTempSKU(var TempStockkeepingUnit: Record "Stockkeeping Unit" temporary; InventoryProfile: Record "Inventory Profile")
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforePostInvChgReminder(var InventoryProfileChangeReminder: Record "Inventory Profile"; var InventoryProfile: Record "Inventory Profile"; PostOnlyMinimum: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnAfterPostInvChgReminder(var InventoryProfileChangeReminder: Record "Inventory Profile"; var InventoryProfile: Record "Inventory Profile"; PostOnlyMinimum: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnEndOfPrePlanDateApplicationLoop(var SupplyInventoryProfile: Record "Inventory Profile"; var DemandInventoryProfile: Record "Inventory Profile"; var SupplyExists: Boolean; var DemandExists: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnMaintainPlanningLineOnAfterReqLineInsert(var RequisitionLine: Record "Requisition Line")
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnMaintainPlanningLineOnBeforeReqLineInsert(var RequisitionLine: Record "Requisition Line"; var SupplyInvtProfile: Record "Inventory Profile"; PlanToDate: Date; CurrentForecast: Code[10]; NewPhase: Option " ", "Line Created", "Routing Created", Exploded, Obsolete; Direction: Option Forward, Backward; DemandInvtProfile: Record "Inventory Profile")
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnPlanItemOnBeforeSumDemandInvtProfile(DemandInvtProfile: Record "Inventory Profile"; var IsHandled: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnPlanItemOnBeforeSumSupplyInvtProfile(SupplyInvtProfile: Record "Inventory Profile"; var IsHandled: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnBeforeMaintainProjectedInventory(var ReminderInvtProfile: Record "Inventory Profile"; AtDate: Date; var LastProjectedInventory: Decimal; var LatestBucketStartDate: Date; var ROPHasBeenCrossed: Boolean; var IsHandled: Boolean)
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnMaintainPlanningLineOnAfterLineCreated(var SupplyInvtProfile: Record "Inventory Profile"; var RequisitionLine: Record "Requisition Line")
    begin
    end;
    [IntegrationEvent(false, false)]
    local procedure OnCalculatePlanFromWorksheetOnAfterPlanItem(CurrTemplateName: Code[10]; CurrWorksheetName: Code[10]; var Item: Record "Item"; var RequisitionLine: Record "Requisition Line"; var TrackingReservEntry: Record "Reservation Entry")
    begin
    end;
}
