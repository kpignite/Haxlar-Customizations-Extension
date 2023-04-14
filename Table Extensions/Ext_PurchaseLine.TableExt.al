tableextension 50002 Ext_PurchaseLine extends "Purchase Line"
{
    fields
    {
        // Add changes to table fields here
        field(50000; ETA; Date)
        {
        }
        field(50001; Cstm_Description; Text[200])
        {
        }
        field(50002; Notes; Text[200])
        {
        }
        field(50003; Remarks; Text[200])
        {
        }
        modify("No.")
        {
        trigger OnAfterValidate()
        var
            Item: Record Item;
        begin
            Validate(Cstm_Description, Description);
        end;
        }
    }
    trigger OnInsert()
    var
        myInt: Integer;
    begin
        Type:=Type::Item;
    end;
    var myInt: Integer;
}
