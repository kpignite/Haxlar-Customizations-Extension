pageextension 50016 Ext_SalesQuote extends "Sales Quote"
{
    layout
    {
        // Add changes to page layout here
        addafter("Invoice Details")
        {
            group("Program Terms")
            {
                field("Tooling Lead Time"; Rec."Tooling Lead Time")
                {
                    ApplicationArea = all;
                    ShowMandatory = true;
                }
                field("Sample Lead Time"; Rec."Sample Lead Time")
                {
                    ApplicationArea = all;
                    ShowMandatory = true;
                }
                field("Production Lead Time"; Rec."Production Lead Time")
                {
                    ApplicationArea = all;
                    ShowMandatory = true;
                }
                field("Transit Lead Time"; Rec."Transit Lead Time")
                {
                    ApplicationArea = all;
                    ShowMandatory = true;
                }
                field("Quoted Currency"; Rec."Quoted Currency")
                {
                    ApplicationArea = all;
                    ShowMandatory = true;
                }
                field("Tooling Payment Terms"; Rec."Tooling Payment Terms")
                {
                    ApplicationArea = all;
                    ShowMandatory = true;
                }
                field("Production Terms"; Rec."Production Terms")
                {
                    ApplicationArea = all;
                    ShowMandatory = true;
                }
                field("PPAP Requirement"; Rec."PPAP Requirement")
                {
                    ApplicationArea = all;
                    ShowMandatory = true;
                }
                field("Technical Review"; Rec."Technical Review")
                {
                    ApplicationArea = all;
                    ShowMandatory = true;
                }
            }
            group("Users Information")
            {
                field(UserName; Rec.UserName)
                {
                    ApplicationArea = all;
                }
                field(UserEmail; Rec.UserEmail)
                {
                    ApplicationArea = all;
                }
                field(UserPhone; Rec.UserPhone)
                {
                    ApplicationArea = all;
                }
            }
        }
        addafter(Status)
        {
            field(IncoTerms; Rec.IncoTerms)
            {
                ApplicationArea = all;
                LookupPageId = IncoTermsList;
                ShowMandatory = true;
                Importance = Promoted;
            }
        }
        modify("Shipment Method Code")
        {
            ShowMandatory = true;
        }
        modify("Your Reference")
        {
            ShowMandatory = true;
            Importance = Promoted;
        }
        modify("Sell-to Customer Name")
        {
            ShowMandatory = true;
            Importance = Promoted;
        }
        modify("Sell-to Contact")
        {
            ShowMandatory = true;
            Importance = Promoted;
        }
        modify("Due Date")
        {
            Visible = false;
        }
        modify("External Document No.")
        {
            Visible = false;
        }
        modify("Invoice Details")
        {
            Visible = false;
        }
        addafter("Invoice Details")
        {
            group("Invoice Detail")
            {
                field("Payment Term Code"; rec."Payment Terms Code")
                {
                    ShowMandatory = true;
                    ApplicationArea = all;
                }
            }
        }
    }
    trigger OnNewRecord(BelowxRex: Boolean)
    var
        myInt: Integer;
    begin
        rec.IncoTerms:='FOB - Haxlar USA Warehouse';
        rec."Payment Terms Code":='2%NET30';
        Rec.UserName:='Zoran Ristic';
        Rec."Quoted Currency":='USD';
        Rec."Tooling Payment Terms":='50% Deposit / 50% on Sample';
        Rec.UserEmail:='ristic.zoran@haxlar.com';
        Rec."Production Terms":='2%-10 / Net-30';
        Rec."PPAP Requirement":='Level 1';
        Rec."Technical Review":='DFM Prior to PO Acceptance';
        Rec.UserPhone:='+1 (734) 239-1116';
    end;
    var myInt: Integer;
}
