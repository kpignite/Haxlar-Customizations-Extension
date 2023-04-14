page 50155 "Replenishment Sub Locations"
{
    // Meg01.00 FS (21-07-21): New Page (FAWAZ-000249)
    PageType = List;
    UsageCategory = Lists;
    ApplicationArea = All;
    SourceTable = "Replenishment Sub Locations";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = all;
                }
                field("Location Name"; Rec."Location Name")
                {
                    ApplicationArea = all;
                }
            }
        }
    }
    actions
    {
    }
}
