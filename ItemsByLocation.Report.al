report 50002 ItemsByLocation
{
    UsageCategory = ReportsAndAnalysis;
    ApplicationArea = All;
    Caption = 'Items by Location';
    RDLCLayout = 'Layouts\ItemByLocation.rdlc';

    dataset
    {
        dataitem(Item_; Item)
        {
            column(Item_No; "No.")
            {
            }
            column(Item_Description; Description)
            {
            }
            column(Qty__on_Purch__Order; "Qty. on Purch. Order")
            {
            }
            column(Reserved_Qty__on_Purch__Orders; "Reserved Qty. on Purch. Orders")
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
            dataitem("Item Ledger Entry"; "Item Ledger Entry")
            {
                RequestFilterFields = "Posting Date";
                DataItemTableView = where("Location Code"=filter(<>'IN-TRANSIT'));
                DataItemLink = "Item No."=field("No.");

                column(Quantity; "Item Ledger Entry".Quantity)
                {
                }
                column(Location_Code; "Item Ledger Entry"."Location Code")
                {
                }
                column(ILE_Reserved; "Item Ledger Entry"."Reserved Quantity")
                {
                }
                trigger OnPreDataItem()
                begin
                    if location <> '' then "Item Ledger Entry".SetFilter("Location Code", location);
                end;
                trigger OnAfterGetRecord()
                begin
                    Clear(Item);
                    if item.Get("Item Ledger Entry"."Item No.")then;
                end;
            }
            trigger OnPreDataItem()
            begin
                if CompanyInfo.FindFirst()then CompanyInfo.CalcFields(Picture);
            end;
            trigger OnAfterGetRecord()
            begin
                Clear(PurchLine);
                CalcFields("Qty. on Purch. Order", "Reserved Qty. on Purch. Orders");
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
    var Item: Record Item;
    CompanyInfo: Record "Company Information";
    location: Code[100];
    PurchLine: Record "Purchase Line";
}
