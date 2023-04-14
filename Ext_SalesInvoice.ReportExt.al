reportextension 50003 Ext_SalesInvoice extends "Standard Sales - Invoice"
{
    RDLCLayout = 'Layout/SalesInvoic.rdlc';

    dataset
    {
        modify(Header)
        {
        trigger OnAfterAfterGetRecord()
        begin
            Clear(CustomerRec);
            if CustomerRec.Get(Header."Sell-to Customer No.")then;
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
            if Line.Quantity = 0 then CurrReport.Skip();
            if Line.Type = Line.Type::Item then begin
                recItem.Reset();
                recitem.SetRange("No.", "No.");
                if recitem.FindFirst()then ItemDescription:=recItem.Description;
            end;
        end;
        }
        add(Header)
        {
            column(CompInfo_Picture; CompInfo.Picture)
            {
            }
            column(CompInfo_Name; CompInfo.Name)
            {
            }
            column(CompInfo_Address; CompInfo.Address)
            {
            }
            column(CompInfo_City; CompInfo.City)
            {
            }
            column(Company_Address; CompInfo.Address + ' ' + CompInfo.City)
            {
            }
            column(CompInfo_Email; CompInfo."E-Mail")
            {
            }
            column(CustomerRec_Name; CustomerRec.Name)
            {
            }
            column(CustomerRec_Address; CustomerRec.Address)
            {
            }
            column(CustomerRec_City; CustomerRec.City)
            {
            }
            column(CustomerRec_PostCode; CustomerRec."Post Code")
            {
            }
            column(CustomerRec_Country; CustomerRec."Country/Region Code")
            {
            }
            column(Customer_Address; CustomerRec.Address + ' ' + CustomerRec.City + ' ' + CustomerRec."Post Code" + ' ' + CustomerRec."Country/Region Code")
            {
            }
            column(ShipToName; Header."Ship-to Name")
            {
            }
            column(ShipToAddress; Header."Ship-to Address")
            {
            }
            column(ShipToCity; Header."Ship-to City")
            {
            }
            column(ShipToPostCode; Header."Ship-to Post Code")
            {
            }
            column(ShipToCountry; Header."Ship-to County")
            {
            }
            column(ShipTo_Address; Header."Ship-to Address" + ' ' + Header."Ship-to City" + ' ' + Header."Ship-to Post Code" + ' ' + Header."Ship-to County")
            {
            }
            column(Shipment_Method_Code; Header."Shipment Method Code")
            {
            }
            column(PONumber; Header."Order No.")
            {
            }
            column(PINumber; Header."No.")
            {
            }
            column(PostingDate; Header."Posting Date")
            {
            }
            column(PaymentTerms; Header."Payment Terms Code")
            {
            }
            column(Due_Date; Header."Due Date")
            {
            }
            column(Sales_Comment; Header."Sales Comment")
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
    }
    requestpage
    {
    }
    trigger OnPreReport()
    begin
        Clear(CompInfo);
        CompInfo.Get();
        CompInfo.CalcFields(Picture);
    end;
    var CompInfo: Record "Company Information";
    CustomerRec: Record Customer;
    recItem: Record Item;
    ItemDescription: Text[100];
}
