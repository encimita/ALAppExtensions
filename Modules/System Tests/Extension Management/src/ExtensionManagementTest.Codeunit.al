codeunit 133100 "Extension Management Test"
{

    // For the purpose of this test, two sample extensions are pre-published.
    // The condition for the tests to pass is that one of the extensions is holding a dependency on the other one, and they are both 1st Party Extensions, version 1.0.
    // The appIds' of the two extensions are set in the SetNavAppIds procedure.
    // The two extensions are pre-build outside the testing extension , and it is only the resulting .app files that are moved to a "testArtifacts" folder within this test extension.
    // The tests script will therefore publish the two extensions separately so the tests in this codeunit can execute and complete succesfully.


    Subtype = Test;
    TestPermissions = NonRestrictive;

    trigger OnRun()
    begin
    end;

    var
        ExtensionManagement: Codeunit "Extension Management";
        Assert: Codeunit "Library Assert";
        MainAppId: Guid;
        DependingAppId: Guid;
        IsInitialized: Boolean;
        NotInstalledSuccErr: Label 'Extension was not installed succesfully';
        NotUninstalledSuccErr: Label 'Extension has not been uninstalled succesfully';
        MainExtNotInstalledSuccErr: Label 'The extension the current extension is depending on was not installed succesfully';
        DependingExtNotInstalledSuccErr: Label 'The extension depending on the current extension was not uninstalled succesfully';
        ExtensionInstalleddErr: Label 'Extension should not be installed';
        ExtensionNotInstalledErr: Label 'Extension should be installed.';
        PackageIdExistsErr: Label 'The returned extension pakage does not exist';
        NullPackageIdErr: Label 'There should not be an extension corresponding to the returned package ID';
        PackageIdExtensionVersionErr: Label 'The package Id does not poin to the correct extension version';

    local procedure SetNavAppIds()
    begin
        MainAppId := '9d939f81-be24-481f-9352-830c0346c171';
        DependingAppId := 'c4123d81-a537-4062-bdd4-7b9882bcc319';
    end;

    local procedure InitializeExtensions()
    var
        NAVAppInstalledApp: Record "NAV App Installed App";
    begin

        IF NAVAppInstalledApp.GET(MainAppId) THEN
            ExtensionManagement.UninstallExtension(NAVAppInstalledApp."Package ID", FALSE);
        IF NAVAppInstalledApp.GET(DependingAppId) THEN
            ExtensionManagement.UninstallExtension(NAVAppInstalledApp."Package ID", FALSE);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure InstallUninstallExtension()
    var
        NAVAppInstalledApp: Record "NAV App Installed App";
        MainAppPackageId: Guid;
    begin
        SetNavAppIds();
        InitializeExtensions();

        MainAppPackageId := ExtensionManagement.GetLatestVersionPackageIdByAppId(MainAppId);
        ExtensionManagement.InstallExtension(MainAppPackageId, GlobalLanguage(), FALSE);
        Assert.IsTrue(NAVAppInstalledApp.GET(MainAppId), NotInstalledSuccErr);

        ExtensionManagement.UninstallExtension(MainAppPackageId, FALSE);
        Assert.IsFalse(NAVAppInstalledApp.GET(MainAppId), NotUninstalledSuccErr);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure InstallExtensionDependencies()
    var
        NAVAppInstalledApp: Record "NAV App Installed App";
        MainPackageId: Guid;
    begin
        SetNavAppIds();
        InitializeExtensions();

        MainPackageId := ExtensionManagement.GetLatestVersionPackageIdByAppId(MainAppId);

        ExtensionManagement.InstallExtension(MainPackageId, GlobalLanguage(), FALSE);
        Assert.IsTrue(NAVAppInstalledApp.GET(MainAppId), MainExtNotInstalledSuccErr);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure UninstallExtensionDependents()
    var
        NAVAppInstalledApp: Record "NAV App Installed App";
        MainAppPackageId: Guid;
        DependingAppPackageId: Guid;
    begin
        SetNavAppIds();
        InitializeExtensions();

        MainAppPackageId := ExtensionManagement.GetLatestVersionPackageIdByAppId(MainAppId);
        DependingAppPackageId := ExtensionManagement.GetLatestVersionPackageIdByAppId(DependingAppId);

        ExtensionManagement.InstallExtension(MainAppPackageId, GlobalLanguage(), FALSE);
        ExtensionManagement.InstallExtension(DependingAppPackageId, GlobalLanguage(), FALSE);
        ExtensionManagement.UninstallExtension(MainAppPackageId, FALSE);

        Assert.IsFalse(NAVAppInstalledApp.GET(DependingAppId), DependingExtNotInstalledSuccErr);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure IsExtensionInstalledByPackageId()
    var
        MainAppPackageId: Guid;
    begin
        SetNavAppIds();
        InitializeExtensions();

        MainAppPackageId := ExtensionManagement.GetLatestVersionPackageIdByAppId(MainAppId);

        ExtensionManagement.InstallExtension(MainAppPackageId, GlobalLanguage(), FALSE);
        Assert.IsTrue(ExtensionManagement.IsInstalledByPackageId(MainAppPackageId), ExtensionNotInstalledErr);

        ExtensionManagement.UninstallExtension(MainAppPackageId, FALSE);

        Assert.IsFalse(ExtensionManagement.IsInstalledByPackageId(MainAppPackageId), ExtensionInstalleddErr);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure IsExtensionInstalledByAppId()
    var
        MainAppPackageId: Guid;
    begin
        SetNavAppIds();
        InitializeExtensions();

        MainAppPackageId := ExtensionManagement.GetLatestVersionPackageIdByAppId(MainAppId);

        ExtensionManagement.InstallExtension(MainAppPackageId, GlobalLanguage(), FALSE);
        Assert.IsTrue(ExtensionManagement.IsInstalledByAppId(MainAppId), ExtensionNotInstalledErr);

        ExtensionManagement.UninstallExtension(MainAppPackageId, FALSE);

        Assert.IsFalse(ExtensionManagement.IsInstalledByAppId(MainAppId), ExtensionInstalleddErr);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure GetLatestVersionPackageIdByAppId()
    var
        NAVApp: Record "NAV App";
        PackageId: Guid;
    begin
        SetNavAppIds();

        PackageId := ExtensionManagement.GetLatestVersionPackageIdByAppId(MainAppId);
        Assert.IsTrue(NAVApp.GET(PackageId), PackageIdExistsErr);
        Assert.AreEqual(NAVApp."Version Major", 1, PackageIdExtensionVersionErr);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure GetCurrentlyInstalledVersionPackageIdByAppId()
    var
        NAVApp: Record "NAV App";
        PackageId: Guid;
    begin
        SetNavAppIds();
        InitializeExtensions();

        PackageId := ExtensionManagement.GetCurrentlyInstalledVersionPackageIdByAppId(MainAppId);
        Assert.IsTrue(ISNULLGUID(PackageId), NullPackageIdErr);

        PackageId := ExtensionManagement.GetLatestVersionPackageIdByAppId(MainAppId);
        ExtensionManagement.InstallExtension(PackageId, GlobalLanguage(), FALSE);
        PackageId := ExtensionManagement.GetCurrentlyInstalledVersionPackageIdByAppId(MainAppId);
        Assert.IsTrue(NAVApp.GET(PackageId), PackageIdExistsErr);
        Assert.AreEqual(NAVApp."Version Major", 1, PackageIdExtensionVersionErr);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure GetSpecificVersionPackageIdByAppId()
    var
        NAVApp: Record "NAV App";
        PackageId: Guid;
        NullGuid: Guid;
    begin
        SetNavAppIds();

        PackageId := ExtensionManagement.GetSpecificVersionPackageIdByAppId(NullGuid, '', 0, 0, 0, 0);
        Assert.IsTrue(ISNULLGUID(PackageId), NullPackageIdErr);
        PackageId := ExtensionManagement.GetSpecificVersionPackageIdByAppId(MainAppId, '', 0, 0, 0, 0);
        Assert.IsTrue(NAVApp.GET(PackageId), PackageIdExistsErr);
        PackageId := ExtensionManagement.GetSpecificVersionPackageIdByAppId(MainAppId, '', 1, 0, 0, 0);
        Assert.IsTrue(NAVApp.GET(PackageId), PackageIdExistsErr);
        Assert.AreEqual(NAVApp."Version Major", 1, PackageIdExtensionVersionErr);
        PackageId := ExtensionManagement.GetSpecificVersionPackageIdByAppId(MainAppId, '', 1, 0, 0, 0);
        Assert.IsTrue(NAVApp.GET(PackageId), PackageIdExistsErr);
        Assert.AreEqual(NAVApp."Version Major", 1, PackageIdExtensionVersionErr);
    end;
}

