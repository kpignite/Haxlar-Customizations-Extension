report 50003 ItemsbByPO
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    Caption = 'Items by PO';
    RDLCLayout = 'Layouts\ItemByPO.rdlc';

    dataset
    {
        dataitem("Purchase Line"; "Purchase Line")
        {
            DataItemTableView = where(Type = filter(= 'ITEM'));

            column(Document_No_; "Document No.")
            {
            }
            column(Item_No; "No.")
            {
            }
            column(Item_Description; Description)
            {
            }
            column(Item_Quantity; Quantity)
            {
            }
            column(Item_Qty_Reserved; "Reserved Qty. (Base)")
            {
            }
            column(Qty; Quantity)
            {
            }
            column(Qty_Received; "Quantity Received")
            {
            }
            column(RemainingQty; Quantity - "Quantity Received")
            {
            }
            column(location; "Location Code")
            {
            }
            column(ShipmtMethod; PurchHeader."Shipment Method Code")
            {
            }
            column(CompanyInfo_picture; CompanyInfo.Picture)
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
            column(ProductionDate; PurchHeader."Production Date")
            {
            }

            trigger OnPreDataItem()
            begin
                if CompanyInfo.FindFirst() then
                    CompanyInfo.CalcFields(Picture);
            end;

            trigger OnAfterGetRecord()
            begin
                Clear(Item);
                Clear(PurchHeader);
                if Item.Get("Purchase Line"."No.") then;
                PurchHeader.SetFilter("No.", "Document No.");
                if PurchHeader.FindFirst() then;
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
                    field(location; location)
                    {
                        Caption = 'Location';
                        TableRelation = Location;
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

    var
        Item: Record Item;
        CompanyInfo: Record "Company Information";
        location: Code[100];
        PurchHeader: Record "Purchase Header";
}
