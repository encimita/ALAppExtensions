// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
codeunit 9702 "Cues And KPIs Impl."
{
    Permissions = TableData "Cue Setup" = r;
    Access = Internal;

    trigger OnRun()
    begin
    end;

    var
        TempGlobalCueSetup: Record "Cue Setup" temporary;
        WrongThresholdsErr: Label '%1 must be greater than %2.', Comment = '%1 Upper threshold %2 Lower threshold';

    [Scope('OnPrem')]
    procedure OpenCustomizePageForCurrentUser(TableId: Integer)
    var
        TempCueSetupRecord: Record "Cue Setup" temporary;
    begin
        // Set TableNo in filter group 2, which is invisible and unchangeable for the user.
        // The user should only be able to set personal styles/thresholds, and only for the given table.
        TempCueSetupRecord.FilterGroup(2);
        TempCueSetupRecord.SetRange("Table ID", TableId);
        TempCueSetupRecord.FilterGroup(0);
        PAGE.RunModal(PAGE::"Cue Setup End User", TempCueSetupRecord);
    end;

    [Scope('OnPrem')]
    procedure PopulateTempCueSetupRecords(var TempCueSetupPageSourceRec: Record "Cue Setup" temporary)
    var
        CueSetup: Record "Cue Setup";
        "Field": Record "Field";
    begin
        // Populate temporary records with appropriate records from the real table.
        CueSetup.CopyFilters(TempCueSetupPageSourceRec);
        CueSetup.SetFilter("User Name", '%1|%2', UserId(), '');

        // Insert user specific records and company wide records.
        CueSetup.Ascending := false;
        if CueSetup.FindSet() then
            repeat
                TempCueSetupPageSourceRec.Copy(CueSetup);
                TempCueSetupPageSourceRec.Personalized := TempCueSetupPageSourceRec."User Name" <> '';
                TempCueSetupPageSourceRec."User Name" := CopyStr(UserId(), 1, 50);
                if TempCueSetupPageSourceRec.Insert() then;
            until CueSetup.Next() = 0;

        // Insert default records
        // Look up in the Fields virtual table
        // Filter on Table No=Table No and Type=Decimal|Integer. This should give us approximately the
        // fields that are "valid" for a cue control.
        Field.SetFilter(TableNo, TempCueSetupPageSourceRec.GetFilter("Table ID"));
        Field.SetFilter(Type, '%1|%2', Field.Type::Decimal, Field.Type::Integer);
        Field.SetFilter(ObsoleteState, '<>%1', Field.ObsoleteState::Removed);
        if Field.FindSet() then begin
            repeat
                if not TempCueSetupPageSourceRec.Get(UserId(), Field.TableNo, Field."No.") then begin
                    TempCueSetupPageSourceRec.Init();
                    TempCueSetupPageSourceRec."User Name" := CopyStr(UserId(), 1, 50);
                    TempCueSetupPageSourceRec."Table ID" := Field.TableNo;
                    TempCueSetupPageSourceRec."Field No." := Field."No.";
                    TempCueSetupPageSourceRec.Personalized := false;
                    TempCueSetupPageSourceRec.Insert();
                end;
            until Field.Next() = 0;

            // Clear last filter
            TempCueSetupPageSourceRec.SetRange("Field No.");
            if TempCueSetupPageSourceRec.FindFirst() then;
        end;
    end;

    [Scope('OnPrem')]
    procedure CopyTempCueSetupRecordsToTable(var TempCueSetupPageSourceRec: Record "Cue Setup" temporary)
    var
        CueSetup: Record "Cue Setup";
    begin
        if TempCueSetupPageSourceRec.FindSet() then
            repeat
                if TempCueSetupPageSourceRec.Personalized then begin
                    CueSetup.TransferFields(TempCueSetupPageSourceRec);
                    if CueSetup.Find() then begin
                        CueSetup.TransferFields(TempCueSetupPageSourceRec);
                        // Personalized field contains temporary property we never save it in the database.
                        CueSetup.Personalized := false;
                        CueSetup.Modify()
                    end else begin
                        // Personalized field contains temporary property we never save it in the database.
                        CueSetup.Personalized := false;
                        CueSetup.Insert();
                    end;
                end else begin
                    CueSetup.TransferFields(TempCueSetupPageSourceRec);
                    if CueSetup.Delete() then;
                end;
            until TempCueSetupPageSourceRec.Next() = 0;

        TempGlobalCueSetup.DeleteAll();
    end;

    [Scope('OnPrem')]
    procedure ValidatePersonalizedField(var TempCueSetupPageSourceRec: Record "Cue Setup" temporary)
    var
        CueSetup: Record "Cue Setup";
    begin
        if TempCueSetupPageSourceRec.Personalized = false then
            if CueSetup.Get('', TempCueSetupPageSourceRec."Table ID", TempCueSetupPageSourceRec."Field No.") then begin
                // Revert back to company default if present.
                TempCueSetupPageSourceRec."Low Range Style" := CueSetup."Low Range Style";
                TempCueSetupPageSourceRec."Threshold 1" := CueSetup."Threshold 1";
                TempCueSetupPageSourceRec."Middle Range Style" := CueSetup."Middle Range Style";
                TempCueSetupPageSourceRec."Threshold 2" := CueSetup."Threshold 2";
                TempCueSetupPageSourceRec."High Range Style" := CueSetup."High Range Style";
            end else begin
                // Revert to "no values".
                TempCueSetupPageSourceRec."Low Range Style" := TempCueSetupPageSourceRec."Low Range Style"::None;
                TempCueSetupPageSourceRec."Threshold 1" := 0;
                TempCueSetupPageSourceRec."Middle Range Style" := TempCueSetupPageSourceRec."Middle Range Style"::None;
                TempCueSetupPageSourceRec."Threshold 2" := 0;
                TempCueSetupPageSourceRec."High Range Style" := TempCueSetupPageSourceRec."High Range Style"::None;
            end;
    end;

    local procedure GetCustomizedCueStyleOption(TableId: Integer; FieldNo: Integer; CueValue: Decimal): Integer
    var
        CueSetup: Record "Cue Setup";
    begin
        FindCueSetup(CueSetup, TableId, FieldNo);
        if CueValue < CueSetup."Threshold 1" then
            exit(CueSetup."Low Range Style");
        if CueValue > CueSetup."Threshold 2" then
            exit(CueSetup."High Range Style");
        exit(CueSetup."Middle Range Style");
    end;

    local procedure FindCueSetup(var CueSetup: Record "Cue Setup"; TableId: Integer; FieldNo: Integer)
    var
        Found: Boolean;
    begin
        if not TempGlobalCueSetup.Get(UserId(), TableId, FieldNo) then begin
            Found := CueSetup.Get(UserId(), TableId, FieldNo);
            if not Found then
                Found := CueSetup.Get('', TableId, FieldNo);
            if Found then
                TempGlobalCueSetup := CueSetup
            else begin // add default to cache
                TempGlobalCueSetup.Init();
                TempGlobalCueSetup."Table ID" := TableId;
                TempGlobalCueSetup."Field No." := FieldNo;
            end;
            TempGlobalCueSetup."User Name" := CopyStr(UserId(), 1, 50);
            TempGlobalCueSetup.Insert();
        end;
        CueSetup := TempGlobalCueSetup;
    end;

    [Scope('OnPrem')]
    procedure ConvertStyleToStyleText(Style: Enum "Cues And KPIs Style"): Text
    var
        CueSetup: Record "Cue Setup";
    begin
        case Style of
            CueSetup."Middle Range Style"::None:
                exit('None');
            CueSetup."Middle Range Style"::Favorable:
                exit('Favorable');
            CueSetup."Middle Range Style"::Unfavorable:
                exit('Unfavorable');
            CueSetup."Middle Range Style"::Ambiguous:
                exit('Ambiguous');
            CueSetup."Middle Range Style"::Subordinate:
                exit('Subordinate');
            else
                exit('');
        end;
    end;

    [Scope('OnPrem')]
    procedure ChangeUserForSetupEntry(var RecRef: RecordRef; Company: Text[30]; UserName: Text[50])
    var
        CueSetup: Record "Cue Setup";
    begin
        CueSetup.ChangeCompany(Company);
        RecRef.SetTable(CueSetup);
        CueSetup.Rename(UserName, CueSetup."Table ID", CueSetup."Field No.");
    end;

    [Scope('OnPrem')]
    procedure SetCueStyle(TableID: Integer; FieldID: Integer; Amount: Decimal; var FinalStyle: Enum "Cues And KPIs Style")
    var
        CueSetup: Record "Cue Setup";
        LowRangeStyle: Enum "Cues And KPIs Style";
        Threshold1: Decimal;
        MiddleRangeStyle: Enum "Cues And KPIs Style";
        Threshold2: Decimal;
        HighRangeStyle: Enum "Cues And KPIs Style";
    begin
        // First see if we have a record for the current user
        if CueSetup.Get(UserId(), TableID, FieldID) then begin
            LowRangeStyle := CueSetup."Low Range Style";
            Threshold1 := CueSetup."Threshold 1";
            MiddleRangeStyle := CueSetup."Middle Range Style";
            Threshold2 := CueSetup."Threshold 2";
            HighRangeStyle := CueSetup."High Range Style";
        end else begin
            CueSetup.Reset();
            CueSetup.SetRange("Table ID", TableID);
            CueSetup.SetRange("Field No.", FieldID);
            if CueSetup.FindFirst() then begin
                LowRangeStyle := CueSetup."Low Range Style";
                Threshold1 := CueSetup."Threshold 1";
                MiddleRangeStyle := CueSetup."Middle Range Style";
                Threshold2 := CueSetup."Threshold 2";
                HighRangeStyle := CueSetup."High Range Style";
            end else begin
                LowRangeStyle := CueSetup."Low Range Style"::None;
                Threshold1 := 0;
                MiddleRangeStyle := CueSetup."Middle Range Style"::None;
                Threshold2 := 0;
                HighRangeStyle := CueSetup."High Range Style"::None;
            end;
        end;

        case true of
            (Amount < Threshold1):
                FinalStyle := LowRangeStyle;
            (Amount > Threshold2):
                FinalStyle := HighRangeStyle;
            else
                FinalStyle := MiddleRangeStyle;
        end;

    end;

    procedure InsertData(TableID: Integer; FieldNo: Integer; LowRangeStyle: Enum "Cues And KPIs Style"; Threshold1: Decimal; MiddleRangeStyle: Enum "Cues And KPIs Style"; Threshold2: Decimal; HighRangeStyle: Enum "Cues And KPIs Style"): Boolean
    var
        CueSetup: Record "Cue Setup";
    begin
        CueSetup.Init();
        CueSetup."Table ID" := TableID;
        CueSetup."Field No." := FieldNo;
        CueSetup."Low Range Style" := LowRangeStyle;
        CueSetup."Threshold 1" := Threshold1;
        CueSetup."Middle Range Style" := MiddleRangeStyle;
        CueSetup."Threshold 2" := Threshold2;
        CueSetup."High Range Style" := HighRangeStyle;
        ValidateThresholds(CueSetup);
        exit(CueSetup.Insert());
    end;

    [EventSubscriber(ObjectType::Codeunit, 2000000004, 'GetCueStyle', '', false, false)]
    local procedure GetCueStyle(TableId: Integer; FieldNo: Integer; CueValue: Decimal; var StyleText: Text)
    var
        Style: Enum "Cues And KPIs Style";
    begin
        Style := GetCustomizedCueStyleOption(TableId, FieldNo, CueValue);
        StyleText := ConvertStyleToStyleText(Style);
    end;

    [Scope('OnPrem')]
    procedure ValidateThresholds(CueSetup: Record "Cue Setup")
    begin
        if CueSetup."Threshold 2" <= CueSetup."Threshold 1" then
            Error(
              WrongThresholdsErr,
              CueSetup.FieldCaption("Threshold 2"),
              CueSetup.FieldCaption("Threshold 1"));
    end;
}

