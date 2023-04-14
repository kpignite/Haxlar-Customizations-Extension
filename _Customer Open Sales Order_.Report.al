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
            column(Year; Year)
            {
            }
            column(JanuaryAmount; PerMonthAmount[1])
            {
            }
            column(FebruaryAmount; PerMonthAmount[2])
            {
            }
            column(MarchAmount; PerMonthAmount[3])
            {
            }
            column(AprilAmount; PerMonthAmount[4])
            {
            }
            column(MayAmount; PerMonthAmount[5])
            {
            }
            column(JuneAmount; PerMonthAmount[6])
            {
            }
            column(JulyAmount; PerMonthAmount[7])
            {
            }
            column(AugustAmount; PerMonthAmount[8])
            {
            }
            column(SeptemberAmount; PerMonthAmount[9])
            {
            }
            column(OctoberAmount; PerMonthAmount[10])
            {
            }
            column(NovemberAmount; PerMonthAmount[11])
            {
            }
            column(DecemberAmount; PerMonthAmount[12])
            {
            }
            column(JanuaryTotal; PerMonthTotal[1])
            {
            }
            column(FebruaryTotal; PerMonthTotal[2])
            {
            }
            column(MarchTotal; PerMonthTotal[3])
            {
            }
            column(AprilTotal; PerMonthTotal[4])
            {
            }
            column(MayTotal; PerMonthTotal[5])
            {
            }
            column(JuneTotal; PerMonthTotal[6])
            {
            }
            column(JulyTotal; PerMonthTotal[7])
            {
            }
            column(AugustTotal; PerMonthTotal[8])
            {
            }
            column(SeptemberTotal; PerMonthTotal[9])
            {
            }
            column(OctoberTotal; PerMonthTotal[10])
            {
            }
            column(NovemberTotal; PerMonthTotal[11])
            {
            }
            column(DecemberTotal; PerMonthTotal[12])
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
                if recCompanyInformation.FindFirst()then recCompanyInformation.CalcFields(Picture);
                Year:=Date2DMY(Today, 3);
                Evaluate(ThisYearStartDate, '0101' + Format(Year) + 'D');
                Evaluate(ThisYearEndDate, '1231' + Format(Year) + 'D');
                Evaluate(NextYearEndDate, '1231' + Format(Year + 1) + 'D');
                Clear(PerMonthTotal);
                Clear(PerCustomer1YTotal);
                Clear(PerCustomer2YTotal);
            end;
            trigger OnAfterGetRecord()
            begin
                Clear(PerMonthAmount);
                Clear(PerCustomer1YAmount);
                Clear(PerCustomer2YAmount);
                recSalesHeader.Reset();
                recSalesHeader.SetFilter("Document Type", '%1', recSalesHeader."Document Type"::Order);
                recSalesHeader.SetRange("Sell-to Customer No.", "No.");
                if recSalesHeader.FindSet()then begin
                    repeat recSalesLine.Reset();
                        recSalesLine.SetRange("Document No.", recSalesHeader."No.");
                        recSalesLine.SetFilter("Planned Shipment Date", '%1..%2', ThisYearStartDate, ThisYearEndDate);
                        if recSalesLine.FindSet()then begin
                            repeat case Date2DMY(recSalesLine."Planned Shipment Date", 2)of 1: begin
                                    PerMonthAmount[1]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[1]+=recSalesLine."Amount Including VAT";
                                end;
                                2: begin
                                    PerMonthAmount[2]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[2]+=recSalesLine."Amount Including VAT";
                                end;
                                3: begin
                                    PerMonthAmount[3]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[3]+=recSalesLine."Amount Including VAT";
                                end;
                                4: begin
                                    PerMonthAmount[4]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[4]+=recSalesLine."Amount Including VAT";
                                end;
                                5: begin
                                    PerMonthAmount[5]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[5]+=recSalesLine."Amount Including VAT";
                                end;
                                6: begin
                                    PerMonthAmount[6]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[6]+=recSalesLine."Amount Including VAT";
                                end;
                                7: begin
                                    PerMonthAmount[7]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[7]+=recSalesLine."Amount Including VAT";
                                end;
                                8: begin
                                    PerMonthAmount[8]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[8]+=recSalesLine."Amount Including VAT";
                                end;
                                9: begin
                                    PerMonthAmount[9]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[9]+=recSalesLine."Amount Including VAT";
                                end;
                                10: begin
                                    PerMonthAmount[10]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[10]+=recSalesLine."Amount Including VAT";
                                end;
                                11: begin
                                    PerMonthAmount[11]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[11]+=recSalesLine."Amount Including VAT";
                                end;
                                12: begin
                                    PerMonthAmount[12]+=recSalesLine."Amount Including VAT";
                                    PerMonthTotal[12]+=recSalesLine."Amount Including VAT";
                                end;
                                end;
                            until recSalesLine.Next() = 0;
                        end;
                        recSalesLine.Reset();
                        recSalesLine.SetRange("Document No.", recSalesHeader."No.");
                        recSalesLine.SetFilter("Planned Shipment Date", '%1..%2', ThisYearStartDate, NextYearEndDate);
                        if recSalesLine.FindSet()then begin
                            repeat PerCustomer2YAmount+=recSalesLine."Amount Including VAT";
                                PerCustomer2YTotal+=recSalesLine."Amount Including VAT";
                            until recSalesLine.Next() = 0;
                        end;
                    until recSalesHeader.Next() = 0;
                end;
                for Index:=1 to 12 do PerCustomer1YAmount+=PerMonthAmount[Index];
                PerCustomer1YTotal+=PerCustomer1YAmount;
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
    var recCompanyInformation: Record "Company Information";
    recSalesHeader: Record "Sales Header";
    recSalesLine: Record "Sales Line";
    Year: Integer;
    ThisYearStartDate: Date;
    ThisYearEndDate: Date;
    NextYearEndDate: Date;
    PerMonthAmount: array[12]of Decimal;
    PerMonthTotal: array[12]of Decimal;
    PerCustomer1YAmount: Decimal;
    PerCustomer1YTotal: Decimal;
    PerCustomer2YAmount: Decimal;
    PerCustomer2YTotal: Decimal;
    Index: Integer;
}
