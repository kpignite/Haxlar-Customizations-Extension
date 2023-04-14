table 50000 "Replenishment Sub Locations"
{
    fields
    {
        field(1; "Main Location Code"; Code[10])
        {
            DataClassification = ToBeClassified;
            NotBlank = true;
            TableRelation = Location WHERE("Use As In-Transit"=filter(false));

            trigger OnValidate()
            begin
                TESTFIELD("Main Location Code");
                IF "Location Code" = "Main Location Code" THEN FIELDERROR("Main Location Code");
                CALCFIELDS("Main Location Name");
            end;
        }
        field(2; "Location Code"; Code[10])
        {
            DataClassification = ToBeClassified;
            NotBlank = true;
            TableRelation = Location WHERE("Use As In-Transit"=FIlter(false));

            trigger OnValidate()
            begin
                TESTFIELD("Main Location Code");
                IF "Location Code" = "Main Location Code" THEN FIELDERROR("Location Code");
                CALCFIELDS("Location Name");
            end;
        }
        field(100; "Main Location Name"; Text[100])
        {
            CalcFormula = Lookup(Location.Name WHERE(Code=FIELD("Main Location Code")));
            Editable = false;
            FieldClass = FlowField;
        }
        field(110; "Location Name"; Text[100])
        {
            CalcFormula = Lookup(Location.Name WHERE(Code=FIELD("Location Code")));
            Editable = false;
            FieldClass = FlowField;
        }
    }
    keys
    {
        key(Key1; "Main Location Code", "Location Code")
        {
        }
    }
    fieldgroups
    {
    }
}
