report 50005 ItemSoDetailReport
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    Caption = 'ItemSODetailReport';
    RDLCLayout = 'Layouts\ItemSoDetailReport.rdlc';

    dataset
    {
        dataitem("sales line"; "Sales Line")
        {
            DataItemTableView = where(Type=filter(='ITEM'));

            column(Document_No_; SalesHeader."No.")
            {
            }
            column(Item_No; "No.")
            {
            }
            column(Item_Description; Description)
            {
            }
            column(Qty; Quantity)
            {
            }
            column(Planned_Delivery_Date; "Planned Delivery Date")
            {
            }
            column(CustomerName; SalesHeader."Sell-to Customer Name")
            {
            }
            column(recCompanyInformation_Picture; recCompanyInformation.Picture)
            {
            }
            column(CompanyInfo_Name; CompanyInfo.Name)
            {
            }
            column(CompanyInfo_Address; CompanyInfo.Address)
            {
            }
            column(CompanyInfo_City; CompanyInfo.City)
            {
            }
            dataitem(Integer; Integer)
            {
                DataItemTableView = sorting(Number);

                column(PurchOrder; ReservEntry."Source ID")
                {
                }
                column(PONumber; PONumber)
                {
                }
                column(POQty; POQty)
                {
                }
                column(PODueDate; PODueDate)
                {
                }
                column(Note; Note)
                {
                }
                column(VendorName; Vendor.Name)
                {
                }
                column(ETA; ETA)
                {
                }
                column(QtyNotDelivered; QtyNotDelivered)
                {
                }
                column(ActualShippingQty; ActualShippingQty)
                {
                }
                column(SONumber; SONumber)
                {
                }
                column(QtyDelivered; QtyDelivered)
                {
                }
                column(Ontime; Ontime)
                {
                }
                column(Remarks; Remarks)
                {
                }
                column(Notes; Notes)
                {
                }
                column(DayDiff; DayDiff)
                {
                }
                trigger OnPreDataItem()
                begin
                    Clear(PONumber);
                    Clear(POQty);
                    Clear(PODueDate);
                    Clear(Note);
                    Clear(Vendor);
                    Clear(ETA);
                    Clear(QtyNotDelivered);
                    Clear(ActualShippingQty);
                    Clear(SONumber);
                    Clear(QtyDelivered);
                    Clear(Ontime);
                    Clear(Remarks);
                    Clear(Notes);
                    Clear(DayDiff);
                    ReservationEntry.SetRange("Reservation Status", ReservationEntry."Reservation Status"::Reservation);
                    ReservationEntry.SetFilter("Source Type", '37');
                    ReservationEntry.SetRange("Source Subtype", ReservationEntry."Source Subtype"::"1");
                    ReservationEntry.SetFilter("Source ID", "sales line"."Document No.");
                    ReservationEntry.SetRange("Source Ref. No.", "sales line"."Line No.");
                    if ReservationEntry.FindSet()then SetRange(Number, 1, ReservationEntry.Count)
                    else
                        SetRange(Number, 1, 1);
                end;
                trigger OnAfterGetRecord()
                begin
                    if Number = 1 then begin
                        if ReservationEntry.FindFirst()then;
                    end
                    else
                        ReservationEntry.Next();
                    Clear(PONumber);
                    Clear(POQty);
                    Clear(PODueDate);
                    Clear(Note);
                    Clear(Vendor);
                    Clear(ETA);
                    Clear(QtyNotDelivered);
                    Clear(ActualShippingQty);
                    Clear(SONumber);
                    Clear(QtyDelivered);
                    Clear(Ontime);
                    Clear(Remarks);
                    Clear(Notes);
                    Clear(DayDiff);
                    SONumber:=ReservationEntry."Source ID";
                    if ReservEntry.Get(ReservationEntry."Entry No.", TRUE)then begin
                        if ReservEntry."Source Type" = DATABASE::"Purchase Line" then begin
                            PONumber:=ReservEntry."Source ID";
                            Clear(PurchLine);
                            PurchLine.SetFilter("Document No.", ReservEntry."Source ID");
                            PurchLine.SetRange("Document Type", ReservEntry."Source Subtype");
                            PurchLine.SetRange("Line No.", ReservEntry."Source Ref. No.");
                            if PurchLine.FindFirst()then begin
                                POQty:=PurchLine.Quantity;
                                PODueDate:=PurchLine."Expected Receipt Date";
                                Vendor.Get(PurchLine."Buy-from Vendor No.");
                                ETA:=PurchLine.ETA;
                                QtyNotDelivered:=PurchLine.Quantity;
                                ActualShippingQty:=PurchLine."Quantity Received";
                                Remarks:=PurchLine.Remarks;
                                Notes:=PurchLine.Notes;
                            end;
                        end
                        else if ReservEntry."Source Type" = DATABASE::"Item Ledger Entry" then begin
                                ItemLedgEntry.Reset();
                                ;
                                ItemLedgEntry.SetRange("Entry No.", ReservEntry."Source Ref. No.");
                                if ItemLedgEntry.FindFirst()then begin
                                    if ItemLedgEntry."Entry Type" = ItemLedgEntry."Entry Type"::Purchase then begin
                                        if ItemLedgEntry."Document Type" = ItemLedgEntry."Document Type"::"Purchase Receipt" then begin
                                            Clear(PurchRcptLine);
                                            Clear(QtyNotDelivered);
                                            QtyNotDelivered:=ItemLedgEntry."Remaining Quantity";
                                            PurchRcptLine.SetFilter("Document No.", ItemLedgEntry."Document No.");
                                            PurchRcptLine.SetRange(Type, PurchRcptLine.type::Item);
                                            PurchRcptLine.SetRange("Line No.", ItemLedgEntry."Document Line No.");
                                            if PurchRcptLine.FindFirst()then begin
                                                Clear(PurchLine);
                                                PurchLine.SetFilter("Document No.", PurchRcptLine."Order No.");
                                                PurchLine.SetRange("Line No.", PurchRcptLine."Order Line No.");
                                                if PurchLine.FindFirst()then begin
                                                    POQty:=PurchLine.Quantity;
                                                    PONumber:=PurchLine."Document No.";
                                                    PODueDate:=PurchLine."Expected Receipt Date";
                                                    Vendor.Get(PurchLine."Buy-from Vendor No.");
                                                    ETA:=PurchLine.ETA;
                                                    ActualShippingQty:=PurchLine."Quantity Received";
                                                    Remarks:=PurchLine.Remarks;
                                                    Notes:=PurchLine.Notes;
                                                end
                                                else
                                                begin
                                                    Clear(PurchInvHeader);
                                                    Clear(PurchInvLine);
                                                    PurchInvLine.SetFilter("Document No.", PurchRcptLine."Order No.");
                                                    PurchInvLine.SetRange("Line No.", PurchRcptLine."Order Line No.");
                                                    if PurchInvLine.FindFirst()then begin
                                                        POQty:=PurchInvLine.Quantity;
                                                        PODueDate:=PurchInvLine."Expected Receipt Date";
                                                        Vendor.Get(PurchInvLine."Buy-from Vendor No.");
                                                        ETA:=PurchInvLine.ETD;
                                                        ActualShippingQty:=PurchInvLine.Quantity;
                                                        Remarks:=PurchInvLine.Remarks;
                                                        Notes:=PurchInvLine.Notes;
                                                    end;
                                                end;
                                            end;
                                        end;
                                    end
                                    else if ItemLedgEntry."Entry Type" = ItemLedgEntry."Entry Type"::Transfer then begin
                                            if ItemLedgEntry."Document Type" = ItemLedgEntry."Document Type"::"Transfer Receipt" then QtyDelivered:=ItemLedgEntry.Quantity;
                                        end;
                                end;
                            end;
                    end;
                    Ontime:=true;
                    Clear(DayProc);
                    CompanyInfo.Get();
                    CalendarMgt.SetSource(CompanyInfo, CustomCalendarChange);
                    Clear(DayProc);
                    Clear(NextWorkingday);
                    Clear(DayDiff);
                    if((ETA > "sales line"."Planned Delivery Date") and (ETA <> 0D))then begin
                        repeat if NextWorkingday = 0D then NextWorkingday:="sales line"."Planned Delivery Date"
                            else
                                NextWorkingday:=NextWorkingday + 1;
                            if not CalendarMgt.IsNonworkingDay(NextWorkingday, CustomCalendarChange)then DayDiff+=1;
                        until NextWorkingday + 1 = ETA;
                    end;
                    if daydiff > 14 then ontime:=false;
                end;
            }
            trigger OnPreDataItem()
            begin
                if CompanyInfo.FindFirst()then CompanyInfo.CalcFields(Picture);
                recCompanyInformation.Reset();
                if recCompanyInformation.FindFirst()then recCompanyInformation.CalcFields(Picture);
            end;
            trigger OnAfterGetRecord()
            begin
                Clear(Item);
                Clear(SalesHeader);
                Clear(ReservationEntry);
                if Item.Get("sales line"."No.")then;
                SalesHeader.SetFilter("No.", "Document No.");
                if SalesHeader.FindFirst()then;
            end;
        }
    }
    requestpage
    {
        layout
        {
            area(Content)
            {
                group(General)
                {
                }
            }
        }
        actions
        {
            area(processing)
            {
                action(ActionName)
                {
                    ApplicationArea = All;
                }
            }
        }
    }
    var Item: Record Item;
    CompanyInfo: Record "Company Information";
    location: Code[100];
    SalesHeader: Record "Sales Header";
    ReservationEntry: Record "Reservation Entry";
    ReservEntry: Record "Reservation Entry";
    PurchHeader: Record "Purchase Header";
    PurchLine: Record "Purchase Line";
    PONumber: Code[20];
    POQty: Decimal;
    PODueDate: Date;
    Note: Text[100];
    ItemLedgEntry: Record "Item Ledger Entry";
    PurchRcptLine: Record "Purch. Rcpt. Line";
    PurchInvHeader: Record "Purch. Inv. Header";
    PurchInvLine: Record "Purch. Inv. Line";
    Vendor: Record Vendor;
    ETA: Date;
    QtyNotDelivered: Decimal;
    ActualShippingQty: Decimal;
    SONumber: Code[20];
    Customer: Record customer;
    QtyDelivered: Decimal;
    Ontime: Boolean;
    Remarks: Text;
    Notes: text;
    DayDiff: Integer;
    DayProc: Boolean;
    CustomCalendarChange: record "Customized Calendar Change";
    NextWorkingday: Date;
    CalendarMgt: Codeunit "Calendar Management";
    recCompanyInformation: Record "Company Information";
}
