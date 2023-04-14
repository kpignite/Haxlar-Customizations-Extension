report 50004 ItemsbBySO
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    Caption = 'Items by SO';
    RDLCLayout = 'Layouts\ItemBySO.rdlc';

    dataset
    {
        dataitem("sales line"; "Sales Line")
        {
            DataItemTableView = where(Type = filter(= 'ITEM'));

            column(Document_No_; SalesHeader."Your Reference")
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
            column(Qty_Shipped; "Quantity Shipped")
            {
            }
            column(RemainingQty; Quantity - "Quantity Shipped")
            {
            }
            column(location; "Location Code")
            {
            }
            column(ShipmtMethod; SalesHeader."Shipment Method Code")
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

            trigger OnPreDataItem()
            begin
                if CompanyInfo.FindFirst() then
                    CompanyInfo.CalcFields(Picture);
            end;

            trigger OnAfterGetRecord()
            begin
                Clear(Item);
                Clear(SalesHeader);
                if Item.Get("sales line"."No.") then;
                SalesHeader.SetFilter("No.", "Document No.");
                if SalesHeader.FindFirst() then;
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
        SalesHeader: Record "Sales Header";
}
