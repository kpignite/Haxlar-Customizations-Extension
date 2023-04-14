reportextension 50002 Ext_PurchInv extends "Purchase Invoice NA"
{
    RDLCLayout = 'Layout/PurchInvoic.rdlc';

    dataset
    {
        modify("Purch. Inv. Header")
        {
            trigger OnAfterAfterGetRecord()
            begin
                Clear(VendorRec);
                if VendorRec.Get("Purch. Inv. Header"."Buy-from Vendor No.") then;
            end;
        }

        add("Purch. Inv. Header")
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
            column(CompInfo_Email; CompInfo."E-Mail")
            {
            }
            column(Company_Address; CompInfo.Address + ' ' + CompInfo.City)
            {
            }
            column(VendorRec_Name; VendorRec.Name)
            {
            }
            column(VendorRec_Address; VendorRec.Address)
            {
            }
            column(VendorRec_City; VendorRec.City)
            {
            }
            column(VendorRec_PostCode; VendorRec."Post Code")
            {
            }
            column(VendorRec_Country; VendorRec."Country/Region Code")
            {
            }
            column(Vendor_Address; VendorRec.Address + ' ' + VendorRec.City + ' ' + VendorRec."Post Code" + ' ' + VendorRec."Country/Region Code")
            {
            }
            column(ShipToName; "Purch. Inv. Header"."Ship-to Name")
            {
            }
            column(ShipToAddress; "Purch. Inv. Header"."Ship-to Address")
            {
            }
            column(ShipToCity; "Purch. Inv. Header"."Ship-to City")
            {
            }
            column(ShipToPostCode; "Purch. Inv. Header"."Ship-to Post Code")
            {
            }
            column(ShipToCountry; "Purch. Inv. Header"."Ship-to County")
            {
            }
            column(ShipTo_Address; "Purch. Inv. Header"."Ship-to Address" + ' ' + "Purch. Inv. Header"."Ship-to City" + ' ' + "Purch. Inv. Header"."Ship-to Post Code" + ' ' + "Purch. Inv. Header"."Ship-to County")
            {
            }
            column(Shipment_Method_Code; "Purch. Inv. Header"."Shipment Method Code")
            {
            }
            column(PONumber; "Purch. Inv. Header"."Order No.")
            {
            }
            column(PINumber; "Purch. Inv. Header"."No.")
            {
            }
            column(PostingDate; "Purch. Inv. Header"."Posting Date")
            {
            }
            column(PaymentTerms; "Purch. Inv. Header"."Payment Terms Code")
            {
            }
            column(Due_Date; "Purch. Inv. Header"."Due Date")
            {
            }
            column(Purchase_Comment; "Purch. Inv. Header"."Purchase Comment")
            {
            }
            column(Inco_Terms; "Purch. Inv. Header"."Inco Terms")
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

    var
        CompInfo: Record "Company Information";
        VendorRec: Record Vendor;
}
