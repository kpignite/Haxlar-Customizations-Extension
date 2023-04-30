reportextension 50004 Ext_PurchOrder extends "Purchase Order"
{
    dataset
    {
        add("Purchase Header")
        {
            column(CompInfo_Picture; CompInfo.Picture)
            {
            }
            column("IncoTerms"; "Purchase Header"."Inco Terms")
            {
            }
            column(CompInfo_Address; CompInfo.Address + ' ' + CompInfo.City)
            {
            }
            column(BuyFromVendorName; "Buy-from Vendor Name")
            {
            }
            column(BuyFromVendorAddress; "Buy-from Address" + ' ' + "Buy-from City" + ' ' + "Buy-from Post Code" + ' ' + "Buy-from Country/Region Code")
            {
            }
            column(ShipToName; "Ship-to Name")
            {
            }
            column(ShipToAddress; "Ship-to Address" + ' ' + "Ship-to City" + ' ' + "Ship-to Post Code" + ' ' + "Ship-to Country/Region Code")
            {
            }
            column(DueDate; "Due Date")
            {
            }
            column(Document_Date; "Document Date")
            {
            }
            column(Posting_Date; "Posting Date")
            {
            }
        }
    }

    requestpage
    {
        // Add changes to the requestpage here
    }

    rendering
    {
        layout("Purchase Order Layout without Tooling Paragraph")
        {
            Type = RDLC;
            LayoutFile = 'Layouts/PurchOrder.rdlc';
        }

        layout("Purchase Order Layout with Tooling Paragraph")
        {
            Type = RDLC;
            LayoutFile = 'Layouts/ExtPurchaseOrder.rdlc';
        }
    }

    trigger OnPreReport()
    begin
        Clear(CompInfo);
        CompInfo.Get();
        CompInfo.CalcFields(Picture);
    end;

    var
        CompInfo: Record "Company Information";
}