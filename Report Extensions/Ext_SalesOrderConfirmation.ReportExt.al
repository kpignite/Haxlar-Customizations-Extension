reportextension 50001 Ext_SalesOrderConfirmation extends "Standard Sales - Order Conf."
{
    RDLCLayout = 'Layouts/StandardSalesOrderConf.rdlc';

    dataset
    {
        add(Header)
        {
            column(No_; "No.")
            {
            }
            column(CompanyInformation_Picture; recCompanyInformation.Picture)
            {
            }
            column(CompanyInformation_Address; recCompanyInformation.Address + ' ' + recCompanyInformation.City)
            {
            }
            column(CustomerName; recCustomer.Name)
            {
            }
            column(CustomerAddress; recCustomer.Address + ' ' + recCustomer.City + ' ' + recCustomer."Post Code" + ' ' + recCustomer."Country/Region Code")
            {
            }
            column(ShipToName; "Ship-to Name")
            {
            }
            column(ShipToAddress; "Ship-to Address" + ' ' + "Ship-to City" + ' ' + "Ship-to Post Code" + ' ' + "Ship-to County")
            {
            }
            column(ShipmentMethodCode; "Shipment Method Code")
            {
            }
            column(Posting_Date; "Posting Date")
            {
            }
            column(Due_Date; "Due Date")
            {
            }
            column(Payment_Terms_Code; "Payment Terms Code")
            {
            }
            column(IncoTerms; IncoTerms)
            {
            }
        }

        add(Line)
        {
            column(Cstm_Description; Cstm_Description)
            {
            }
            column(ItemDescription; ItemDescription)
            {
            }
        }

        modify(Header)
        {
            trigger OnAfterPreDataItem()
            begin
                recCompanyInformation.Reset();
                if recCompanyInformation.FindFirst() then
                    recCompanyInformation.CalcFields(Picture);
            end;

            trigger OnAfterAfterGetRecord()
            begin
                recCustomer.Reset();
                recCustomer.SetRange("No.", "Sell-to Customer No.");
                if recCustomer.FindFirst() then;
            end;
        }

        modify(Line)
        {
            trigger OnAfterPreDataItem()
            begin
                Clear(ItemDescription);
            end;

            trigger OnAfterAfterGetRecord()
            begin
                if Line.Type = Line.Type::Item then begin
                    recItem.Reset();
                    recItem.SetRange("No.", "No.");
                    if recItem.FindFirst() then
                        ItemDescription := recItem.Description;
                end;
            end;
        }
    }

    requestpage
    {
    }

    var
        recCompanyInformation: Record "Company Information";
        recCustomer: Record Customer;
        recItem: Record Item;
        ItemDescription: Text[100];
}
