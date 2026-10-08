#!/usr/bin/env python3
"""Deterministic, dependency-free Xcode project generator. Does not touch source files."""
from pathlib import Path
import hashlib, json
root = Path(__file__).resolve().parent.parent
objects = {}
def ident(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(object_key, isa, **kw):
    key=ident(object_key);objects[key]={'isa':isa,**kw};return key
def ref(path, kind='sourcecode.swift'):
    return obj('file:'+path,'PBXFileReference',lastKnownFileType=kind,path=path,sourceTree='SOURCE_ROOT')
def configs(name, common):
    items=[]
    for config in ['Debug','Release']:
        settings={**common,'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O',
                  'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if config=='Debug' else '',
                  'ENABLE_TESTABILITY':'YES' if config=='Debug' else 'NO'}
        items.append(obj(name+config,'XCBuildConfiguration',name=config,buildSettings=settings))
    return obj(name+'configs','XCConfigurationList',buildConfigurations=items,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
package=obj('package','XCLocalSwiftPackageReference',relativePath='.')
productRefs=[]; fileRefs=[]; targets=[]
def target(name, productType, productExt, paths, libraries, settings, deps=[]):
    product=obj(name+'product','PBXFileReference',explicitFileType='wrapper.application' if productExt=='.app' else 'wrapper.cfbundle',includeInIndex=0,path=('biochem_tool_kit' if productExt=='.app' else name)+productExt,sourceTree='BUILT_PRODUCTS_DIR')
    productRefs.append(product)
    buildFiles=[]
    for path in paths:
        file=ref(path); fileRefs.append(file)
        buildFiles.append(obj(name+path,'PBXBuildFile',fileRef=file))
    sources=obj(name+'sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=buildFiles,runOnlyForDeploymentPostprocessing=0)
    packages=[]; frameworks=[]
    for library in libraries:
        dependency=obj(name+library+'dependency','XCSwiftPackageProductDependency',package=package,productName=library)
        packages.append(dependency);frameworks.append(obj(name+library+'build','PBXBuildFile',productRef=dependency))
    phase=obj(name+'frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=frameworks,runOnlyForDeploymentPostprocessing=0)
    resources=obj(name+'resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
    common={'MACOSX_DEPLOYMENT_TARGET':'13.0','SDKROOT':'macosx','SWIFT_VERSION':'5.0','CODE_SIGN_IDENTITY':'-','CODE_SIGN_STYLE':'Manual','COMBINE_HIDPI_IMAGES':'YES',**settings}
    key=obj(name,'PBXNativeTarget',name=name,productName=name,productReference=product,productType=productType,buildConfigurationList=configs(name,common),buildPhases=[sources,phase,resources],buildRules=[],dependencies=deps,packageProductDependencies=packages)
    targets.append(key);return key
app=target('biochem_tool_kit','com.apple.product-type.application','.app',[str(p.relative_to(root)) for p in sorted((root/'Sources/BioChemPet').glob('*.swift'))],['BioChemCore','BioChemUI'],{'PRODUCT_NAME':'biochem_tool_kit','PRODUCT_MODULE_NAME':'BioChemPet','EXECUTABLE_NAME':'BioChemPet','PRODUCT_BUNDLE_IDENTIFIER':'local.biochem.bridge','INFOPLIST_FILE':'Config/Info.plist','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks','ENABLE_HARDENED_RUNTIME':'NO'})
unit=target('BioChemCoreTests','com.apple.product-type.bundle.unit-test','.xctest',[str(p.relative_to(root)) for p in sorted((root/'Tests/BioChemCoreTests').glob('*.swift'))],['BioChemCore','BioChemTestSupport'],{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'local.biochem.coretests','MACOSX_DEPLOYMENT_TARGET':'14.0','GENERATE_INFOPLIST_FILE':'YES','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @loader_path/../Frameworks'})
proxy=obj('appProxy','PBXContainerItemProxy',containerPortal=ident('project'),proxyType=1,remoteGlobalIDString=app,remoteInfo='biochem_tool_kit')
dep=obj('uiAppDependency','PBXTargetDependency',target=app,targetProxy=proxy)
ui=target('biochem_tool_kitUITests','com.apple.product-type.bundle.ui-testing','.xctest',['UITests/biochem_tool_kitUITests.swift'],[],{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'local.biochem.uitests','MACOSX_DEPLOYMENT_TARGET':'14.0','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'biochem_tool_kit','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @loader_path/../Frameworks'},[dep])
products=obj('products','PBXGroup',name='Products',sourceTree='<group>',children=productRefs)
main=obj('mainGroup','PBXGroup',sourceTree='<group>',children=fileRefs+[ref('Config/Info.plist','text.plist.xml'),products])
project=obj('project','PBXProject',attributes={'LastUpgradeCheck':'1600','TargetAttributes':{ui:{'TestTargetID':app}}},buildConfigurationList=configs('project',{'CLANG_ENABLE_MODULES':'YES','SDKROOT':'macosx','MACOSX_DEPLOYMENT_TARGET':'13.0'}),compatibilityVersion='Xcode 14.0',developmentRegion='en',knownRegions=['en','Base'],mainGroup=main,productRefGroup=products,projectDirPath='',projectRoot='',targets=targets,packageReferences=[package])
def encode(value):
    if isinstance(value,dict): return '{\n'+''.join(json.dumps(k)+' = '+encode(v)+';\n' for k,v in value.items())+'}'
    if isinstance(value,list): return '('+''.join(encode(v)+',' for v in value)+')'
    return str(value) if isinstance(value,int) else json.dumps(value,ensure_ascii=False)
folder=root/'biochem_tool_kit.xcodeproj';folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':project})+'\n')
scheme=folder/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
def buildable(key,name,product): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{key}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:biochem_tool_kit.xcodeproj"/>'
a=buildable(app,'biochem_tool_kit','biochem_tool_kit.app');u=buildable(unit,'BioChemCoreTests','BioChemCoreTests.xctest');i=buildable(ui,'biochem_tool_kitUITests','biochem_tool_kitUITests.xctest')
(scheme/'biochem_tool_kit.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{a}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{u}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{i}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{u}</TestableReference><TestableReference skipped="NO">{i}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{a}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print('Generated biochem_tool_kit.xcodeproj (app, existing unit tests, UI tests, shared scheme).')
