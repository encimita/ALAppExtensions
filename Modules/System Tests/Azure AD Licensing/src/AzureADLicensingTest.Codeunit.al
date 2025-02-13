﻿// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

codeunit 138458 "Azure AD Licensing Test"
{
    EventSubscriberInstance = Manual;
    SingleInstance = true;
    Subtype = Test;

    trigger OnRun()
    begin
    end;

    var
        AzureADLicensingTest: Codeunit "Azure AD Licensing Test";
        AzureADLicensing: Codeunit "Azure AD Licensing";
        Assert: Codeunit "Library Assert";
        EnvironmentInfo: Codeunit "Environment Information";
        MockGraphQuery: DotNet MockGraphQuery;
        ServicePlanOneIdTxt: Text;
        ServicePlanTwoIdTxt: Text;
        ServicePlanThreeIdTxt: Text;
        SubscribedSkuOneIdTxt: Text;
        SubscribedSkuTwoIdTxt: Text;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Azure AD Graph", 'OnInitialize', '', false, false)]
    local procedure SetMockGraphQuery(var GraphQuery: DotNet GraphQuery)
    begin
        GraphQuery := GraphQuery.GraphQuery(MockGraphQuery);
    end;

    local procedure Initialize()
    var
        SubscribedSkuOne: DotNet SkuInfo;
        SubscribedSkuTwo: DotNet SkuInfo;
        ServicePlanInfoOne: DotNet ServicePlanInfo;
        ServicePlanInfoTwo: DotNet ServicePlanInfo;
        ServicePlanInfoThree: DotNet ServicePlanInfo;
        LicenseUnitsDetailOne: DotNet LicenseUnitsInfo;
        LicenseUnitsDetailTwo: DotNet LicenseUnitsInfo;
        ServicePlanOneId: Guid;
        ServicePlanTwoId: Guid;
        ServicePlanThreeId: Guid;
        SubscribedSkuOneId: Guid;
        SubscribedSkuTwoId: Guid;
    begin
        EnvironmentInfo.SetTestabilitySoftwareAsAService := true;

        Clear(AzureADLicensing);
        AzureADLicensing.SetTestInProgress(true);

        MockGraphQuery := MockGraphQuery.MockGraphQuery();

        ServicePlanOneId := CREATEGUID();
        ServicePlanTwoId := CREATEGUID();
        ServicePlanThreeId := CREATEGUID();
        SubscribedSkuOneId := CREATEGUID();
        SubscribedSkuTwoId := CREATEGUID();

        ServicePlanOneIdTxt := COPYSTR(FORMAT(ServicePlanOneId), 2, STRLEN(FORMAT(ServicePlanOneId)) - 2);
        ServicePlanTwoIdTxt := COPYSTR(FORMAT(ServicePlanTwoId), 2, STRLEN(FORMAT(ServicePlanTwoId)) - 2);
        ServicePlanThreeIdTxt := COPYSTR(FORMAT(ServicePlanThreeId), 2, STRLEN(FORMAT(ServicePlanThreeId)) - 2);

        SubscribedSkuOneIdTxt := COPYSTR(FORMAT(SubscribedSkuOneId), 1, STRLEN(FORMAT(SubscribedSkuOneId)));
        SubscribedSkuTwoIdTxt := COPYSTR(FORMAT(SubscribedSkuTwoId), 1, STRLEN(FORMAT(SubscribedSkuTwoId)));

        //Create Service Plans Info
        CreateServicePlanInfo(ServicePlanInfoOne, ServicePlanOneId, 'Plan Capability Status One', 'Plan name One');
        CreateServicePlanInfo(ServicePlanInfoTwo, ServicePlanTwoId, 'Plan Capability Status Two', 'Plan name Two');
        CreateServicePlanInfo(ServicePlanInfoThree, ServicePlanThreeId, 'Plan Capability Status Three', 'Plan name Three');

        //Create License units details
        CreateLicenseUnitsDetail(LicenseUnitsDetailOne, 1, 1, 1);
        CreateLicenseUnitsDetail(LicenseUnitsDetailTwo, 2, 2, 2);

        //Create Subscribed SKUs
        //Add Service Plan Info to the Subscribed SKUs
        CreateSubscribedSKU(SubscribedSkuOne, LicenseUnitsDetailOne, SubscribedSkuOneId,
        'SKU Object Id One', 'SKU Capability Status One', 'SKU Part number One', 1, 1);
        SubscribedSkuOne.ServicePlans().Add(ServicePlanInfoOne);
        SubscribedSkuOne.ServicePlans().Add(ServicePlanInfoTwo);

        CreateSubscribedSKU(SubscribedSkuTwo, LicenseUnitsDetailTwo, SubscribedSkuTwoId,
        'SKU Object Id Two', 'SKU Capability Status Two', 'SKU Part number Two', 2, 2);
        SubscribedSkuTwo.ServicePlans().Add(ServicePlanInfoOne);
        SubscribedSkuTwo.ServicePlans().Add(ServicePlanInfoThree);

        //Add the subscribed SKUs to the Graph Query
        MockGraphQuery.AddDirectorySubscribedSku(SubscribedSkuOne);
        MockGraphQuery.AddDirectorySubscribedSku(SubscribedSkuTwo);
    end;

    local procedure CreateServicePlanInfo(var ServicePlanInfo: DotNet ServicePlanInfo; Guid: Guid; CapabilityStatus: Text; Name: Text)
    begin
        ServicePlanInfo := ServicePlanInfo.ServicePlanInfo();
        ServicePlanInfo.ServicePlanId := Guid;
        ServicePlanInfo.CapabilityStatus := CapabilityStatus;
        ServicePlanInfo.ServicePlanName := Name;
    end;

    local procedure CreateSubscribedSKU(var SubscribedSku: DotNet SkuInfo; LicenseUnitsDetail: DotNet LicenseUnitsInfo; SkuId: Guid; ObjectId: Text; CapabilityStatus: Text; SkuPartNumber: Text; ConsumedUnits: Integer; NrPrepaidUnitsInEnabledState: Integer)
    begin
        SubscribedSku := SubscribedSku.SkuInfo();
        SubscribedSku.PrepaidUnits := LicenseUnitsDetail;
        SubscribedSku.SkuId := SkuId;
        SubscribedSku.ObjectId := ObjectId;
        SubscribedSku.CapabilityStatus := CapabilityStatus;
        SubscribedSku.SkuPartNumber := SkuPartNumber;
        SubscribedSku.ConsumedUnits := ConsumedUnits;
    end;

    [Scope('OnPrem')]
    procedure CreateLicenseUnitsDetail(var LicenseUnitsDetailOne: DotNet LicenseUnitsInfo; NrUnitsInEnabledState: Integer; NrUnitsInSuspendedState: Integer; NrUnitsInWarningState: Integer)
    begin
        LicenseUnitsDetailOne := LicenseUnitsDetailOne.LicenseUnitsInfo();
        LicenseUnitsDetailOne.Enabled := NrUnitsInEnabledState;
        LicenseUnitsDetailOne.Suspended := NrUnitsInSuspendedState;
        LicenseUnitsDetailOne.Warning := NrUnitsInWarningState;
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    [Scope('OnPrem')]
    procedure TestSubscribedSKUCapabilityStatus()
    begin
        // [SCENARIO] Capability Status of a subscribed SKU is correctly retrieved

        Initialize();

        // [Given] A mock SKU data
        BINDSUBSCRIPTION(AzureADLicensingTest);
        AzureADLicensing.ResetSubscribedSKU();
        AzureADLicensing.SetIncludeUnknownPlans(TRUE);

        // [When] Query the first Subscribed SKU object
        // [WHEN] SubscribedSKUCapabilityStatus is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] Its capability status is as expected
        Assert.AreEqual('SKU Capability Status One', AzureADLicensing.SubscribedSKUCapabilityStatus(), 'Wrong subscribed SKU capability status!');

        // [When] Query the second Subscribed SKU object
        // [WHEN] SubscribedSKUCapabilityStatus is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] Its capability status is as expected
        Assert.AreEqual('SKU Capability Status Two', AzureADLicensing.SubscribedSKUCapabilityStatus(), 'Wrong subscribed SKU capability status!');

        // [When] Try to query the third Subscribed SKU object
        // [WHEN] SubscribedSKUCapabilityStatus is called
        // [THEN] NextSubscribedSKU should return FALSE and last capability status should be returned
        Assert.AreEqual(FALSE, AzureADLicensing.NextSubscribedSKU(), 'Next subscribed SKU is not as expected.');
        Assert.AreEqual('SKU Capability Status Two', AzureADLicensing.SubscribedSKUCapabilityStatus(), 'Wrong SKU capability status!');

        UNBINDSUBSCRIPTION(AzureADLicensingTest);
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    [Scope('OnPrem')]
    procedure TestSubscribedSKUConsumedUnits()
    begin
        // [SCENARIO] Consumed units of a subscribed SKU is correctly retrieved

        // [Given] A mock SKU data
        BINDSUBSCRIPTION(AzureADLicensingTest);
        AzureADLicensing.ResetSubscribedSKU();
        AzureADLicensing.SetIncludeUnknownPlans(TRUE);

        // [When] Query the first Subscribed SKU object
        // [WHEN] SubscribedSKUConsumedUnits is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] Its consumed units are as correctly retrieved
        Assert.AreEqual(1, AzureADLicensing.SubscribedSKUConsumedUnits(), 'Wrong subscribed SKU consumed units!');

        // [When] Query the second Subscribed SKU object
        // [WHEN] SubscribedSKUConsumedUnits is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] Its consumed units are correctly retrieved
        Assert.AreEqual(2, AzureADLicensing.SubscribedSKUConsumedUnits(), 'Wrong subscribed SKU consumed units!');

        // [When] Try to query the third Subscribed SKU object
        // [WHEN] SubscribedSKUConsumedUnits is called
        // [THEN] NextSubscribedSKU should return FALSE and the consumed units of the last subscribed sku should be returned
        Assert.AreEqual(FALSE, AzureADLicensing.NextSubscribedSKU(), 'Next subscribed SKU is not as expected.');
        Assert.AreEqual(2, AzureADLicensing.SubscribedSKUConsumedUnits(), 'Wrong subscribed SKU consumed units!');

        UNBINDSUBSCRIPTION(AzureADLicensingTest);
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    [Scope('OnPrem')]
    procedure TestSubscribedSKUObjectId()
    begin
        // [SCENARIO] Object Id of a subscribed SKU is correctly retrieved

        // [Given] A mock SKU data
        BINDSUBSCRIPTION(AzureADLicensingTest);
        AzureADLicensing.ResetSubscribedSKU();
        AzureADLicensing.SetIncludeUnknownPlans(TRUE);

        // [When] Query the first Subscribed SKU object
        // [WHEN] SubscribedSKUObjectId is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] Its object id is as expected
        Assert.AreEqual('SKU Object Id One', AzureADLicensing.SubscribedSKUObjectId(), 'Wrong Object ID for the first subscribed SKU!');

        // [When] Query the second Subscribed SKU object
        // [WHEN] SubscribedSKUObjectId is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] Its object id is as expected
        Assert.AreEqual('SKU Object Id Two', AzureADLicensing.SubscribedSKUObjectId(), 'Wrong Object ID for the second subscribed SKU!');

        // [When] Try to query the third Subscribed SKU object
        // [WHEN] SubscribedSKUObjectId is called
        // [THEN] NextSubscribedSKU should return FALSE and last object id is returned
        Assert.AreEqual(FALSE, AzureADLicensing.NextSubscribedSKU(), 'Next subscribed SKU is not as expected.');
        Assert.AreEqual('SKU Object Id Two', AzureADLicensing.SubscribedSKUObjectId(), 'Wrong subscribed SKU Object ID!');

        UNBINDSUBSCRIPTION(AzureADLicensingTest);
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    [Scope('OnPrem')]
    procedure TestSubscribedSKUPrepaidUnitsInEnabledState()
    begin
        // [SCENARIO] Prepaid units in enabled state of a subscribed SKU is correctly retrieved

        // [Given] A mock SKU data
        BINDSUBSCRIPTION(AzureADLicensingTest);
        AzureADLicensing.ResetSubscribedSKU();
        AzureADLicensing.SetIncludeUnknownPlans(TRUE);

        // [When] Query the first Subscribed SKU object
        // [WHEN] SubscribedSKUPrepaidUnitsInEnabledState is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] The nr of units in enabled state is as expected
        Assert.AreEqual(1, AzureADLicensing.SubscribedSKUPrepaidUnitsInEnabledState(), 'Wrong nr of units in enabled state for the first subscribed SKU!');

        // [When] Query the second Subscribed SKU object
        // [WHEN] SubscribedSKUPrepaidUnitsInEnabledState is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] The nr of units in enabled state is as expected
        Assert.AreEqual(2, AzureADLicensing.SubscribedSKUPrepaidUnitsInEnabledState(), 'Wrong nr of units in enabled state for the second subscribed SKU!');

        // [When] Try to query the third Subscribed SKU object
        // [WHEN] SubscribedSKUPrepaidUnitsInEnabledState is called
        // [THEN] NextSubscribedSKU should return FALSE
        Assert.AreEqual(FALSE, AzureADLicensing.NextSubscribedSKU(), 'Next subscribed SKU is not as expected.');
        Assert.AreEqual(2, AzureADLicensing.SubscribedSKUPrepaidUnitsInEnabledState(), 'Wrong nr of units in enabled state!');

        UNBINDSUBSCRIPTION(AzureADLicensingTest);
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    [Scope('OnPrem')]
    procedure TestSubscribedSKUPrepaidUnitsInSuspendedState()
    begin
        // [SCENARIO] Prepaid units in suspended state of a subscribed SKU is correctly retrieved

        // [Given] A mock SKU data
        BINDSUBSCRIPTION(AzureADLicensingTest);
        AzureADLicensing.ResetSubscribedSKU();
        AzureADLicensing.SetIncludeUnknownPlans(TRUE);

        // [When] Query the first Subscribed SKU object
        // [WHEN] SubscribedSKUPrepaidUnitsInSuspendedState is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] The nr of units in suspended state is as expected
        Assert.AreEqual(1, AzureADLicensing.SubscribedSKUPrepaidUnitsInSuspendedState(), 'Wrong nr of units in suspended state for the first subscribed SKU!');

        // [When] Query the second Subscribed SKU object
        // [WHEN] SubscribedSKUPrepaidUnitsInSuspendedState is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] The nr of units in suspended state is as expected
        Assert.AreEqual(2, AzureADLicensing.SubscribedSKUPrepaidUnitsInSuspendedState(), 'Wrong nr of units in suspended state for the second subscribed SKU!');

        // [When] Try to query the third Subscribed SKU object
        // [WHEN] SubscribedSKUPrepaidUnitsInSuspendedState is called
        // [THEN] NextSubscribedSKU should return FALSE
        Assert.AreEqual(FALSE, AzureADLicensing.NextSubscribedSKU(), 'Next subscribed SKU is not as expected.');
        Assert.AreEqual(2, AzureADLicensing.SubscribedSKUPrepaidUnitsInSuspendedState(), 'Wrong nr of units in suspended state!');

        UNBINDSUBSCRIPTION(AzureADLicensingTest);
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    [Scope('OnPrem')]
    procedure TestSubscribedSKUPrepaidUnitsInWarningState()
    begin
        // [SCENARIO] Prepaid units in warning state of a subscribed SKU is correctly retrieved

        // [Given] A mock SKU data
        BINDSUBSCRIPTION(AzureADLicensingTest);
        AzureADLicensing.ResetSubscribedSKU();
        AzureADLicensing.SetIncludeUnknownPlans(TRUE);

        // [When] Query the first Subscribed SKU object
        // [WHEN] SubscribedSKUPrepaidUnitsInWarningState is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] The nr of units in warning state is as expected
        Assert.AreEqual(1, AzureADLicensing.SubscribedSKUPrepaidUnitsInWarningState(), 'Wrong nr of units in warning state for the first subscribed SKU!');

        // [When] Query the second Subscribed SKU object
        // [WHEN] SubscribedSKUPrepaidUnitsInWarningState is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] The nr of units in warning state is as expected
        Assert.AreEqual(2, AzureADLicensing.SubscribedSKUPrepaidUnitsInWarningState(), 'Wrong nr of units in warning state for the second subscribed SKU!');

        // [When] Try to query the third Subscribed SKU object
        // [WHEN] SubscribedSKUPrepaidUnitsInWarningState is called
        // [THEN] NextSubscribedSKU should return FALSE
        Assert.AreEqual(FALSE, AzureADLicensing.NextSubscribedSKU(), 'Next subscribed SKU is not as expected.');
        Assert.AreEqual(2, AzureADLicensing.SubscribedSKUPrepaidUnitsInWarningState(), 'Wrong nr of units in warning state!');

        UNBINDSUBSCRIPTION(AzureADLicensingTest);
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    [Scope('OnPrem')]
    procedure TestSubscribedSKUId()
    begin
        // [SCENARIO] ID of a subscribed SKU is correctly retrieved

        // [Given] A mock SKU data
        BINDSUBSCRIPTION(AzureADLicensingTest);
        AzureADLicensing.ResetSubscribedSKU();
        AzureADLicensing.SetIncludeUnknownPlans(TRUE);

        // [When] Query the first Subscribed SKU object
        // [WHEN] SubscribedSKUId is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] The SKU id is correctly retrieved
        Assert.AreEqual(SubscribedSkuOneIdTxt, AzureADLicensing.SubscribedSKUId(), 'Wrong id for the first subscribed SKU!');

        // [When] Query the second Subscribed SKU object
        // [WHEN] SubscribedSKUId is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] The SKU id is correctly retrieved
        Assert.AreEqual(SubscribedSkuTwoIdTxt, AzureADLicensing.SubscribedSKUId(), 'Wrong id for the second subscribed SKU!');

        // [When] Try to query the third Subscribed SKU object
        // [WHEN] SubscribedSKUId is called
        // [THEN] NextSubscribedSKU should return FALSE
        Assert.AreEqual(FALSE, AzureADLicensing.NextSubscribedSKU(), 'Next subscribed SKU is not as expected.');
        Assert.AreEqual(SubscribedSkuTwoIdTxt, AzureADLicensing.SubscribedSKUId(), 'Wrong id retrieved!');

        UNBINDSUBSCRIPTION(AzureADLicensingTest);
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    [Scope('OnPrem')]
    procedure TestSubscribedSKUPartNumber()
    begin
        // [SCENARIO] Part number of a subscribed SKU is correctly retrieved

        // [Given] A mock SKU data
        BINDSUBSCRIPTION(AzureADLicensingTest);
        AzureADLicensing.ResetSubscribedSKU();
        AzureADLicensing.SetIncludeUnknownPlans(TRUE);

        // [When] Query the first Subscribed SKU object
        // [WHEN] SubscribedSKUPartNumber is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] The nr of units in warning state is as expected
        Assert.AreEqual('SKU Part number One', AzureADLicensing.SubscribedSKUPartNumber(), 'Wrong part number e for the first subscribed SKU!');

        // [When] Query the second Subscribed SKU object
        // [WHEN] SubscribedSKUPartNumber is called
        AzureADLicensing.NextSubscribedSKU();

        // [Then] The part number is correctly retrieved
        Assert.AreEqual('SKU Part number Two', AzureADLicensing.SubscribedSKUPartNumber(), 'Wrong part number for the second subscribed SKU!');

        // [When] Try to query the third Subscribed SKU object
        // [WHEN] SubscribedSKUPartNumber is called
        // [THEN] NextSubscribedSKU should return FALSE
        Assert.AreEqual(FALSE, AzureADLicensing.NextSubscribedSKU(), 'Next subscribed SKU is not as expected.');
        Assert.AreEqual('SKU Part number Two', AzureADLicensing.SubscribedSKUPartNumber(), 'Wrong part number!');

        UNBINDSUBSCRIPTION(AzureADLicensingTest);
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    [Scope('OnPrem')]
    procedure TestServicePlanCapabilityStatus()
    begin
        // [SCENARIO] Capability Status of a subscribed service is correctly retrieved

        // [Given] A mock SKU data
        BINDSUBSCRIPTION(AzureADLicensingTest);
        AzureADLicensing.ResetSubscribedSKU();
        AzureADLicensing.ResetServicePlans();
        AzureADLicensing.SetIncludeUnknownPlans(TRUE);

        // [When] Query the first Subscribed SKU object
        // [When] Query the first service plan from the SKU object
        AzureADLicensing.NextSubscribedSKU();
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanCapabilityStatus is called
        // [Then] The capability status is as expected
        Assert.AreEqual('Plan Capability Status One', AzureADLicensing.ServicePlanCapabilityStatus(), 'Wrong capability status for the first service plan in the first subscribed SKU!');

        // [When] Query the second service plan from the SKU object
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanCapabilityStatus is called
        // [Then] The capability status is as expected
        Assert.AreEqual('Plan Capability Status Two', AzureADLicensing.ServicePlanCapabilityStatus(), 'Wrong capability status for the second service plan in the first subscribed SKU!');

        // [When] Query the second Subscribed SKU object
        // [When] Query the first service plan from the SKU object
        AzureADLicensing.NextSubscribedSKU();
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanCapabilityStatus is called
        // [Then] The capability status is as expected
        Assert.AreEqual('Plan Capability Status One', AzureADLicensing.ServicePlanCapabilityStatus(), 'Wrong capability status for the first service plan in the second subscribed SKU!');

        // [When] Query the second plan from the SKU object
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanCapabilityStatus is called
        // [Then] The capability status is as expected
        Assert.AreEqual('Plan Capability Status Three', AzureADLicensing.ServicePlanCapabilityStatus(), 'Wrong capability status for the second service plan in the second subscribed SKU!');

        // [When] Try to query the third service plan
        // [THEN] NextServicePlan should return FALSE
        Assert.AreEqual(FALSE, AzureADLicensing.NextServicePlan(), 'Next service plan is not as expected.');
        // [WHEN] ServicePlanCapabilityStatus is called
        // [THEN] The capability status of the last service plan queried is returned
        Assert.AreEqual('Plan Capability Status Three', AzureADLicensing.ServicePlanCapabilityStatus(), 'Wrong capability status the second subscribed SKU!');

        UNBINDSUBSCRIPTION(AzureADLicensingTest);
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    [Scope('OnPrem')]
    procedure TestServicePlanId()
    begin
        // [SCENARIO] Plan id of a subscribed service is correctly retrieved

        // [Given] A mock SKU data
        BINDSUBSCRIPTION(AzureADLicensingTest);
        AzureADLicensing.ResetSubscribedSKU();
        AzureADLicensing.ResetServicePlans();
        AzureADLicensing.SetIncludeUnknownPlans(TRUE);

        // [When] Query the first Subscribed SKU object
        // [When] Query the first service plan from the SKU object
        AzureADLicensing.NextSubscribedSKU();
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanId is called
        // [Then] The service plan id is correctly retrieved
        Assert.AreEqual(ServicePlanOneIdTxt, AzureADLicensing.ServicePlanId(), 'Wrong plan id for the first service plan in the first subscribed SKU!');

        // [When] Query the second service plan from the SKU object
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanId is called
        // [Then] The service plan id is correctly retrieved
        Assert.AreEqual(ServicePlanTwoIdTxt, AzureADLicensing.ServicePlanId(), 'Wrong plan id for the second service plan in the first subscribed SKU!');

        // [When] Query the second Subscribed SKU object
        // [When] Query the first service plan from the SKU object
        AzureADLicensing.NextSubscribedSKU();
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanId is called
        // [Then] The service plan id is correctly retrieved
        Assert.AreEqual(ServicePlanOneIdTxt, AzureADLicensing.ServicePlanId(), 'Wrong plan id for the first service plan in the second subscribed SKU!');

        // [When] Query the second plan from the SKU object
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanCapabilityStatus is called
        // [Then] The capability status is as expected
        Assert.AreEqual(ServicePlanThreeIdTxt, AzureADLicensing.ServicePlanId(), 'Wrong plan id for the second service plan in the second subscribed SKU!');

        // [When] Try to query the third service plan
        // [THEN] NextServicePlan should return FALSE
        Assert.AreEqual(FALSE, AzureADLicensing.NextServicePlan(), 'Next service plan is not as expected.');
        // [WHEN] ServicePlanId is called
        // [THEN] The plan id of the last service plan returned is retrieved
        Assert.AreEqual(ServicePlanThreeIdTxt, AzureADLicensing.ServicePlanId(), 'Wrong capability status the second subscribed SKU!');

        UNBINDSUBSCRIPTION(AzureADLicensingTest);
    end;

    [Test]
    [TestPermissions(TestPermissions::NonRestrictive)]
    [Scope('OnPrem')]
    procedure TestServicePlanName()
    begin
        // [SCENARIO] The plan name of a subscribed service is correctly retrieved

        // [Given] A mock SKU data
        BINDSUBSCRIPTION(AzureADLicensingTest);
        AzureADLicensing.ResetSubscribedSKU();
        AzureADLicensing.ResetServicePlans();
        AzureADLicensing.SetIncludeUnknownPlans(TRUE);

        // [When] Query the first Subscribed SKU object
        // [When] Query the first service plan from the SKU object
        AzureADLicensing.NextSubscribedSKU();
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanName is called
        // [Then] The service plan name is as expected
        Assert.AreEqual('Plan name One', AzureADLicensing.ServicePlanName(), 'Wrong service plan name!');

        // [When] Query the second service plan from the SKU object
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanName is called
        // [Then] The service plan name is as expected
        Assert.AreEqual('Plan name Two', AzureADLicensing.ServicePlanName(), 'Wrong service plan name!');

        // [When] Query the second Subscribed SKU object
        // [When] Query the first service plan from the SKU object
        AzureADLicensing.NextSubscribedSKU();
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanName is called
        // [Then] The service plan name is as expected
        Assert.AreEqual('Plan name One', AzureADLicensing.ServicePlanName(), 'Wrong service plan name!');

        // [When] Query the second plan from the SKU object
        AzureADLicensing.NextServicePlan();
        // [WHEN] ServicePlanName is called
        // [Then] The service plan name is as expected
        Assert.AreEqual('Plan name Three', AzureADLicensing.ServicePlanName(), 'Wrong service plan name!');

        // [When] Try to query the third service plan
        // [THEN] NextServicePlan should return FALSE
        Assert.AreEqual(FALSE, AzureADLicensing.NextServicePlan(), 'Next service plan is not as expected.');
        // [WHEN] ServicePlanName is called
        // [THEN] The service plan name of the last service plan queried is returned
        Assert.AreEqual('Plan name Three', AzureADLicensing.ServicePlanName(), 'Wrong service plan name!');

        UNBINDSUBSCRIPTION(AzureADLicensingTest);
    end;
}

