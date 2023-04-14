report 50001 CalculateSOPlan
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    ProcessingOnly = true;

    dataset
    {
        dataitem(Item; Item)
        {
            dataitem(Integer; Integer)
            {
                trigger OnPreDataItem()
                var
                    myInt: Integer;
                begin
                    SetRange(Number, 1, Period);
                end;
                trigger OnAfterGetRecord()
                var
                    myInt: Integer;
                begin
                    Clear(SalesLine);
                    Clear(StartDateFilter);
                    Clear(EndDateFilter);
                    Clear(CurrDate);
                    Clear(DateExpr);
                    if Number = 1 then begin
                        StartDateFilter:=CALCDATE('-CM', StartDate);
                        EndDateFilter:=CALCDATE('CM', StartDate);
                    end
                    else
                    begin
                        DateExpr:='<+' + format(Number - 1) + 'M>';
                        CurrDate:=CalcDate(DateExpr, StartDate);
                        StartDateFilter:=CALCDATE('-CM', CurrDate);
                        EndDateFilter:=CALCDATE('CM', CurrDate);
                    end;
                    SalesLine.SetRange("Planned Shipment Date", StartDateFilter, EndDateFilter);
                    SalesLine.SetRange(Type, SalesLine.Type::Item);
                    SalesLine.SetFilter(SalesLine."Document Type", '%1|%2', SalesLine."Document Type"::Order, SalesLine."Document Type"::Invoice);
                    SalesLine.SetFilter("No.", Item."No.");
                    if ForeCastLocation <> '' then SalesLine.SetFilter("Location Code", ForeCastLocation);
                    SalesLine.SetCurrentKey("Document Type", Type, "No.", "Variant Code", "Drop Shipment", "Location Code", "Shipment Date");
                    SalesLine.CalcSums("Outstanding Qty. (Base)");
                    if SalesLine."Outstanding Qty. (Base)" <> 0 then begin
                        Clear(ProdForecastEntry);
                        ProdForecastEntry.init;
                        ProdForecastEntry.validate("Production Forecast Name", ForeCast);
                        ProdForecastEntry."Entry No.":=EntryNo;
                        ProdForecastEntry.Validate("Item No.", Item."No.");
                        ProdForecastEntry.Validate("Forecast Date", StartDateFilter);
                        ProdForecastEntry.Validate("Forecast Quantity", SalesLine."Outstanding Qty. (Base)");
                        ProdForecastEntry.Validate("Qty. per Unit of Measure", 1);
                        ProdForecastEntry.Validate("Forecast Quantity (Base)", SalesLine."Outstanding Qty. (Base)");
                        ProdForecastEntry.Validate("Location Code", ForeCastLocation);
                        ProdForecastEntry.Insert(true);
                    end;
                end;
            }
            trigger OnAfterGetRecord()
            var
                myInt: Integer;
            begin
            end;
        }
    }
    requestpage
    {
        layout
        {
            area(Content)
            {
                group(GroupName)
                {
                    field(StartDate; StartDate)
                    {
                        ApplicationArea = All;
                        Caption = 'Start Date';
                    }
                    field(Period; Period)
                    {
                        ApplicationArea = All;
                        Caption = 'No. Of Period';
                    }
                    field(ForeCast; ForeCast)
                    {
                        ApplicationArea = All;
                        Caption = 'Forecast';
                        TableRelation = "Production Forecast Name";
                    }
                    field(ForeCastLocation; ForeCastLocation)
                    {
                        ApplicationArea = All;
                        Caption = 'Forecast Location';
                        TableRelation = Location;
                    }
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
        trigger OnClosePage()
        var
            myInt: Integer;
        begin
            IF Period = 0 then Error('Specify Number Of Period');
            IF ForeCast = '' then Error('Specify Forecast');
            IF StartDate = 0D then Error('Specify Start Date');
            IF ForeCastLocation = '' then Error('Specify Location');
            ProdForecastEntry.SetFilter("Production Forecast Name", ForeCast);
            ProdForecastEntry.DeleteAll;
        end;
    }
    var StartDate: Date;
    Period: Integer;
    ForeCast: Code[50];
    SalesLine: Record "Sales Line";
    StartDateFilter: date;
    EndDateFilter: Date;
    CurrDate: Date;
    DateExpr: Text[100];
    ProdForecastEntry: Record "Production Forecast Entry";
    ForeCastLocation: Code[20];
    EntryNo: Integer;
}
