report 50006 "Customer Open Sales Order"
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    DefaultRenderingLayout = "Customer Open Sales Order Layout 01";

    dataset
    {
        dataitem(Customer; Customer)
        {
            RequestFilterFields = "No.";

            column(CompanyInformation_Picture; recCompanyInformation.Picture)
            {
            }
            column(CompanyInformation_Name; recCompanyInformation.Name)
            {
            }
            column(CompanyInformation_Address; recCompanyInformation.Address)
            {
            }
            column(CompanyInformation_City; recCompanyInformation.City)
            {
            }
            column(No_; "No.")
            {
            }
            column(Name; Name)
            {
            }
            column(CurrentYear; Year)
            {
            }
            column(NextYear; Year + 1)
            {
            }
            column(JanuaryCurrentYearAmount; PerMonthCurrentYearAmount[1])
            {
            }
            column(FebruaryCurrentYearAmount; PerMonthCurrentYearAmount[2])
            {
            }
            column(MarchCurrentYearAmount; PerMonthCurrentYearAmount[3])
            {
            }
            column(AprilCurrentYearAmount; PerMonthCurrentYearAmount[4])
            {
            }
            column(MayCurrentYearAmount; PerMonthCurrentYearAmount[5])
            {
            }
            column(JuneCurrentYearAmount; PerMonthCurrentYearAmount[6])
            {
            }
            column(JulyCurrentYearAmount; PerMonthCurrentYearAmount[7])
            {
            }
            column(AugustCurrentYearAmount; PerMonthCurrentYearAmount[8])
            {
            }
            column(SeptemberCurrentYearAmount; PerMonthCurrentYearAmount[9])
            {
            }
            column(OctoberCurrentYearAmount; PerMonthCurrentYearAmount[10])
            {
            }
            column(NovemberCurrentYearAmount; PerMonthCurrentYearAmount[11])
            {
            }
            column(DecemberCurrentYearAmount; PerMonthCurrentYearAmount[12])
            {
            }
            column(JanuaryCurrentYearTotal; PerMonthCurrentYearTotal[1])
            {
            }
            column(FebruaryCurrentYearTotal; PerMonthCurrentYearTotal[2])
            {
            }
            column(MarchCurrentYearTotal; PerMonthCurrentYearTotal[3])
            {
            }
            column(AprilCurrentYearTotal; PerMonthCurrentYearTotal[4])
            {
            }
            column(MayCurrentYearTotal; PerMonthCurrentYearTotal[5])
            {
            }
            column(JuneCurrentYearTotal; PerMonthCurrentYearTotal[6])
            {
            }
            column(JulyCurrentYearTotal; PerMonthCurrentYearTotal[7])
            {
            }
            column(AugustCurrentYearTotal; PerMonthCurrentYearTotal[8])
            {
            }
            column(SeptemberCurrentYearTotal; PerMonthCurrentYearTotal[9])
            {
            }
            column(OctoberCurrentYearTotal; PerMonthCurrentYearTotal[10])
            {
            }
            column(NovemberCurrentYearTotal; PerMonthCurrentYearTotal[11])
            {
            }
            column(DecemberCurrentYearTotal; PerMonthCurrentYearTotal[12])
            {
            }
            column(JanuaryNextYearAmount; PerMonthNextYearAmount[1])
            {
            }
            column(FebruaryNextYearAmount; PerMonthNextYearAmount[2])
            {
            }
            column(MarchNextYearAmount; PerMonthNextYearAmount[3])
            {
            }
            column(AprilNextYearAmount; PerMonthNextYearAmount[4])
            {
            }
            column(MayNextYearAmount; PerMonthNextYearAmount[5])
            {
            }
            column(JuneNextYearAmount; PerMonthNextYearAmount[6])
            {
            }
            column(JulyNextYearAmount; PerMonthNextYearAmount[7])
            {
            }
            column(AugustNextYearAmount; PerMonthNextYearAmount[8])
            {
            }
            column(SeptemberNextYearAmount; PerMonthNextYearAmount[9])
            {
            }
            column(OctoberNextYearAmount; PerMonthNextYearAmount[10])
            {
            }
            column(NovemberNextYearAmount; PerMonthNextYearAmount[11])
            {
            }
            column(DecemberNextYearAmount; PerMonthNextYearAmount[12])
            {
            }
            column(JanuaryNextYearTotal; PerMonthNextYearTotal[1])
            {
            }
            column(FebruaryNextYearTotal; PerMonthNextYearTotal[2])
            {
            }
            column(MarchNextYearTotal; PerMonthNextYearTotal[3])
            {
            }
            column(AprilNextYearTotal; PerMonthNextYearTotal[4])
            {
            }
            column(MayNextYearTotal; PerMonthNextYearTotal[5])
            {
            }
            column(JuneNextYearTotal; PerMonthNextYearTotal[6])
            {
            }
            column(JulyNextYearTotal; PerMonthNextYearTotal[7])
            {
            }
            column(AugustNextYearTotal; PerMonthNextYearTotal[8])
            {
            }
            column(SeptemberNextYearTotal; PerMonthNextYearTotal[9])
            {
            }
            column(OctoberNextYearTotal; PerMonthNextYearTotal[10])
            {
            }
            column(NovemberNextYearTotal; PerMonthNextYearTotal[11])
            {
            }
            column(DecemberNextYearTotal; PerMonthNextYearTotal[12])
            {
            }
            column(PerCustomer1YAmount; PerCustomer1YAmount)
            {
            }
            column(PerCustomer1YTotal; PerCustomer1YTotal)
            {
            }
            column(PerCustomer2YAmount; PerCustomer2YAmount)
            {
            }
            column(PerCustomer2YTotal; PerCustomer2YTotal)
            {
            }

            trigger OnPreDataItem()
            begin
                recCompanyInformation.Reset();
                if recCompanyInformation.FindFirst() then
                    recCompanyInformation.CalcFields(Picture);

                Year := Date2DMY(Today, 3);
                Evaluate(ThisYearStartDate, '0101' + Format(Year) + 'D');
                Evaluate(ThisYearEndDate, '1231' + Format(Year) + 'D');
                Evaluate(NextYearStartDate, '0101' + Format(Year + 1) + 'D');
                Evaluate(NextYearEndDate, '1231' + Format(Year + 1) + 'D');

                Clear(PerMonthCurrentYearTotal);
                Clear(PerMonthNextYearTotal);
                Clear(PerCustomer1YTotal);
                Clear(PerCustomer2YTotal);
            end;

            trigger OnAfterGetRecord()
            begin
                Clear(PerMonthCurrentYearAmount);
                Clear(PerMonthNextYearAmount);
                Clear(PerCustomer1YAmount);
                Clear(PerCustomer2YAmount);

                recSalesHeader.Reset();
                recSalesHeader.SetFilter("Document Type", '%1', recSalesHeader."Document Type"::Order);
                recSalesHeader.SetRange("Sell-to Customer No.", "No.");
                if recSalesHeader.FindSet() then begin
                    repeat
                        recSalesLine.Reset();
                        recSalesLine.SetRange("Document No.", recSalesHeader."No.");
                        recSalesLine.SetFilter("Planned Shipment Date", '%1..%2', ThisYearStartDate, ThisYearEndDate);
                        if recSalesLine.FindSet() then begin
                            repeat
                                case Date2DMY(recSalesLine."Planned Shipment Date", 2) of
                                    1:
                                        begin
                                            PerMonthCurrentYearAmount[1] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[1] += recSalesLine."Amount Including VAT";
                                        end;
                                    2:
                                        begin
                                            PerMonthCurrentYearAmount[2] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[2] += recSalesLine."Amount Including VAT";
                                        end;
                                    3:
                                        begin
                                            PerMonthCurrentYearAmount[3] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[3] += recSalesLine."Amount Including VAT";
                                        end;
                                    4:
                                        begin
                                            PerMonthCurrentYearAmount[4] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[4] += recSalesLine."Amount Including VAT";
                                        end;
                                    5:
                                        begin
                                            PerMonthCurrentYearAmount[5] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[5] += recSalesLine."Amount Including VAT";
                                        end;
                                    6:
                                        begin
                                            PerMonthCurrentYearAmount[6] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[6] += recSalesLine."Amount Including VAT";
                                        end;
                                    7:
                                        begin
                                            PerMonthCurrentYearAmount[7] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[7] += recSalesLine."Amount Including VAT";
                                        end;
                                    8:
                                        begin
                                            PerMonthCurrentYearAmount[8] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[8] += recSalesLine."Amount Including VAT";
                                        end;
                                    9:
                                        begin
                                            PerMonthCurrentYearAmount[9] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[9] += recSalesLine."Amount Including VAT";
                                        end;
                                    10:
                                        begin
                                            PerMonthCurrentYearAmount[10] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[10] += recSalesLine."Amount Including VAT";
                                        end;
                                    11:
                                        begin
                                            PerMonthCurrentYearAmount[11] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[11] += recSalesLine."Amount Including VAT";
                                        end;
                                    12:
                                        begin
                                            PerMonthCurrentYearAmount[12] += recSalesLine."Amount Including VAT";
                                            PerMonthCurrentYearTotal[12] += recSalesLine."Amount Including VAT";
                                        end;
                                end;
                            until recSalesLine.Next() = 0;
                        end;

                        recSalesLine.Reset();
                        recSalesLine.SetRange("Document No.", recSalesHeader."No.");
                        recSalesLine.SetFilter("Planned Shipment Date", '%1..%2', NextYearStartDate, NextYearEndDate);
                        if recSalesLine.FindSet() then begin
                            repeat
                                case Date2DMY(recSalesLine."Planned Shipment Date", 2) of
                                    1:
                                        begin
                                            PerMonthNextYearAmount[1] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[1] += recSalesLine."Amount Including VAT";
                                        end;
                                    2:
                                        begin
                                            PerMonthNextYearAmount[2] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[2] += recSalesLine."Amount Including VAT";
                                        end;
                                    3:
                                        begin
                                            PerMonthNextYearAmount[3] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[3] += recSalesLine."Amount Including VAT";
                                        end;
                                    4:
                                        begin
                                            PerMonthNextYearAmount[4] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[4] += recSalesLine."Amount Including VAT";
                                        end;
                                    5:
                                        begin
                                            PerMonthNextYearAmount[5] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[5] += recSalesLine."Amount Including VAT";
                                        end;
                                    6:
                                        begin
                                            PerMonthNextYearAmount[6] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[6] += recSalesLine."Amount Including VAT";
                                        end;
                                    7:
                                        begin
                                            PerMonthNextYearAmount[7] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[7] += recSalesLine."Amount Including VAT";
                                        end;
                                    8:
                                        begin
                                            PerMonthNextYearAmount[8] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[8] += recSalesLine."Amount Including VAT";
                                        end;
                                    9:
                                        begin
                                            PerMonthNextYearAmount[9] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[9] += recSalesLine."Amount Including VAT";
                                        end;
                                    10:
                                        begin
                                            PerMonthNextYearAmount[10] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[10] += recSalesLine."Amount Including VAT";
                                        end;
                                    11:
                                        begin
                                            PerMonthNextYearAmount[11] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[11] += recSalesLine."Amount Including VAT";
                                        end;
                                    12:
                                        begin
                                            PerMonthNextYearAmount[12] += recSalesLine."Amount Including VAT";
                                            PerMonthNextYearTotal[12] += recSalesLine."Amount Including VAT";
                                        end;
                                end;
                            until recSalesLine.Next() = 0;
                        end;
                    until recSalesHeader.Next() = 0;
                end;

                for Index := 1 to 12 do begin
                    PerCustomer1YAmount += PerMonthCurrentYearAmount[Index];
                    PerCustomer2YAmount += PerMonthCurrentYearAmount[Index] + PerMonthNextYearAmount[Index];
                end;

                PerCustomer1YTotal += PerCustomer1YAmount;
                PerCustomer2YTotal += PerCustomer2YAmount;
            end;
        }
    }

    /*
    requestpage
    {
        layout
        {
            area(Content)
            {
                group(GroupName)
                {
                    field(Name; SourceExpression)
                    {
                        ApplicationArea = All;
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
    }
    */

    rendering
    {
        layout("Customer Open Sales Order Layout 01")
        {
            Type = RDLC;
            LayoutFile = 'Layouts/CustomerOpenSalesOrder.rdlc';
        }
    }

    var
        recCompanyInformation: Record "Company Information";
        recSalesHeader: Record "Sales Header";
        recSalesLine: Record "Sales Line";
        Year: Integer;
        ThisYearStartDate: Date;
        ThisYearEndDate: Date;
        NextYearStartDate: Date;
        NextYearEndDate: Date;
        PerMonthCurrentYearAmount: array[12] of Decimal;
        PerMonthCurrentYearTotal: array[12] of Decimal;
        PerMonthNextYearAmount: array[12] of Decimal;
        PerMonthNextYearTotal: array[12] of Decimal;
        PerCustomer1YAmount: Decimal;
        PerCustomer1YTotal: Decimal;
        PerCustomer2YAmount: Decimal;
        PerCustomer2YTotal: Decimal;
        Index: Integer;
}