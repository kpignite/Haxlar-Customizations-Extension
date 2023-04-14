pageextension 50014 Ext_LocationCard extends "Location Card"
{
    actions
    {
        // Add changes to page actions here
        addafter("&Zones")
        {
            action("Replen. Sub Locations")
            {
                ApplicationArea = all;
                Caption = 'Replen. Sub Locations';
                Image = Warehouse;
                Promoted = true;
                PromotedIsBig = true;
                RunObject = Page "Replenishment Sub Locations";
                RunPageLink = "Main Location Code"=FIELD(Code);
            }
        }
    }
    var myInt: Integer;
}
