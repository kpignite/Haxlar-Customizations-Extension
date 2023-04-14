page 50001 IncoTermsList
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = IncoTerms;

    layout
    {
        area(Content)
        {
            group(General)
            {
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                ApplicationArea = All;

                trigger OnAction()
                begin
                end;
            }
        }
    }
    var myInt: Integer;
}
