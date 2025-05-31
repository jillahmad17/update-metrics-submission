import pandas as pd
import re

def classify_version_requirement(req):
    """
    Classifies version requirement strings into unified constraint categories.
    
    Categories and Examples:
    - pinning: Exact version match
        * "1.2.3"
        * "=1.2.3"
        * "==1.2.3"
        * "v1.0.0"
        * "1.2.3-beta"
        * "1.2.3+build123"
        
    - floating-major: Allows any version update
        * "*"
        * "latest"
        * "x.x.x"
        * ">=1.0.0"
        * ">2.0.0"
        * "*.*.* "
        
    - floating-minor: Allows minor and patch updates
        * "1.x"
        * "1.*"
        * "1.x.x"
        * "^1.2.3"
        * "==1.*"
        * "7.*"
        
    - floating-patch: Allows only patch updates
        * "1.2.x"
        * "1.2.*"
        * "~1.2.3"
        * "=0.8.x"
        * "==2.10.*"
        
    - at-most: Upper bound only
        * "<1.2.3"
        * "<=2.0.0"
        * "<1.26.0.dev0"
        
    - fixed-ranging: Version range with both bounds
        * ">=1.2.3 <2.0.0"
        * ">1.0.0 <6.0.0"
        * "<2.8,>=2.4"
        * "1.0.0-2.0.0"
        * "<2.0.0dev,>=1.0.0"
        
    - not-expression: Version exclusion
        * "!=1.2.3"
        * "!1.2.3"
        
    - or-expression: Multiple version ranges
        * "^1.2.0 || ^2.0.0"
        * ">= 1.2.3 || <= 1.2.4"
        * "11 || 12 || 13"
        
    - complex-expression: Complex version constraints
        * ">=1.2.0,~=1.3"
        * "~=1.3.0,<1.4"
        
    - unclassified: Unrecognized patterns
        * "npm:eslint-plugin-i@2.27.5-4"
        
    Parameters:
        req (str): Version requirement string to classify
        
    Returns:
        str: Classification category name
        
    Regular Expression Patterns:
    - Pinned version: ^\d+(\.\d+){0,2}(-[\w\.-]+)?(\+[\w\.-]+)?$
      Matches: Major[.Minor[.Patch]][-PreRelease][+Build]
      
    - Floating major: ^\*\.\*\.\*$ or ['*', 'latest', 'x', 'x.x', 'x.x.x']
      Matches: Wildcard patterns that allow any version
      
    - fixed-ranging: ^[<>]=?\s*\d+(\.\d+){0,2}(\s*,\s*|\s+)[<>]=?\s*\d+(\.\d+){0,2}$
      Matches: Lower and upper bounds with operators
    """
    req = str(req).strip().lower()

    # or-expression: prioritize early
    if '||' in req:
        return 'or-expression'

    # Floating-major
    if req in ['*', 'latest', 'x', 'x.x', 'x.x.x'] or \
       re.match(r'^\*\.\*\.\*$', req) or \
       (req.startswith('>=') and not any(op in req[2:] for op in ['<', '>', '=', '!', '*'])) or \
        (req.startswith('>') and not any(op in req[1:] for op in ['<', '>', '=', '!', '*'])):
        return 'floating-major'

    # Floating-patch
    if re.match(r'^=?=?\d+\.\d+\.x$', req) or re.match(r'^=?=?\d+\.\d+\.\*$', req) or \
       re.match(r'^\d+\.\d+\.x$', req) or \
        (req.startswith('~') and ',' not in req):
        return 'floating-patch'

    # Floating-minor
    if re.match(r'^=?=?\d+\.x(\.x)?$', req) or re.match(r'^=?=?\d+\.x(\.x)?$', req) or re.match(r'^=?=?\d+\.x\.x$', req) or \
       re.match(r'^=?=?\d+\.\*(\.\*)?$', req) or re.match(r'^=?=?\d+\.\*$', req) or req.startswith('^') or re.match(r'^x\.\*$', req):
        return 'floating-minor'

    # Pinning: no operators present at all or version-looking strings (includes pre-release/metadata)
    if re.match(r'^[\w\.\-\+]+$', req) and not any(op in req for op in ['<', '>', '=', '!', '*', 'x']):
        return 'pinning'

    # At-most
    if re.match(r'^<=?\s*\d+(\.\d+){0,2}(-[a-z0-9]+)?$', req) or \
        (req.startswith('<') and not any (op in req[1:] for op in ['=', '>', '!', '*', '~', '^'])) or \
        (req.startswith('<=') and not any (op in req[2:] for op in ['>', '!', '*', '~', '^'])):
        return 'at-most'

    # fixed-ranging
    if (
        re.match(r'^[<>]=?\s*\d+(\.\d+){0,2}(\s*,\s*|\s+)[<>]=?\s*\d+(\.\d+){0,2}$', req) or
        re.match(r'^\d+(\.\d+)?(\.\w+)?\s*-\s*\d+(\.\d+)?(\.\w+)?$', req) or
        # re.match(r'^[<>]=?\s*\d+(\.\d+){0,2}(\s+[<>]=?\s*\d+(\.\d+){0,2})+$', req)
        ('<' in req and '>' in req and not any(op in req for op in ['!', '*', '~', '^']))
    ):
        return 'fixed-ranging'

    # not-expression
    if re.match(r'^!?=?\d+(\.\d+){0,2}$', req) and req.startswith('!'):
        return 'not-expression'
    
    # Pinning with pre-release or build metadata
    if re.match(r'^\d+(\.\d+){0,2}(-[\w\.-]+)?(\+[\w\.-]+)?$', req) or \
        ((req.startswith('=') or req.startswith('==')) and not any(op in req for op in ['<', '>', '!', '*', '~', '^'])):
        return 'pinning'

    # Complex expression
    if any(op in req for op in ['<', '>', '=', '!', '~', '^']):
        return 'complex-expression'

    # Final fallback: if still version-looking or semantic version with pre-release/build metadata
    if re.match(r'^\d+(\.\d+){0,2}(-[\w\.-]+)?(\+[\w\.-]+)?$', req):
        return 'pinning'

    return 'unclassified'

def run_on_file():
    # Paths
    # input_path = '/home/imranur/security-metrics/data/dep_status/other.csv'
    # output_path = '/home/imranur/security-metrics/data/dep_status/other-updated.csv'
    input_path = '/home/imranur/security-metrics/data/dep_status/all_req.csv'
    output_path = '/home/imranur/security-metrics/data/dep_status/all_req-updated.csv'

    # Load, classify, and save
    df = pd.read_csv(input_path)
    df['actual_requirement'] = df['actual_requirement'].astype(str).str.strip()
    df['requirement_pattern'] = df['actual_requirement'].apply(classify_version_requirement)
    df.to_csv(output_path, index=False)

# Test runner
def run_spec_type_tests():
    test_cases = {
        '*': 'floating-major',
        'latest': 'floating-major',
        '~1.2.3': 'floating-patch',
        '^1.2.3': 'floating-minor',
        '1.2.3': 'pinning',
        '1.x.x': 'floating-minor',
        '1.2.x': 'floating-patch',
        '>=1.2.3': 'floating-major',
        '<1.2.3': 'at-most',
        '>=1.2.3 <2.0.0': 'fixed-ranging',
        '>=1.2.3 <1.3.0': 'fixed-ranging',
        '>1.0.0 <6': 'fixed-ranging',
        '>1.0.0 <6.0': 'fixed-ranging', 
        '>=1.2.3 <5.0.0': 'fixed-ranging',
        '>2.0.0 <6.0.0': 'fixed-ranging',
        '^1.2.0 || ^2.0.0': 'or-expression',
        '>= 1.2.3 || <= 1.2.4': 'or-expression',
        '>= 1.2.3 <= 1.2.4': 'fixed-ranging',
        '<2.0.0 || >=1.2.3': 'or-expression',
        'npm:eslint-plugin-i@2.27.5-4': 'unclassified',
        '<2.8,>=2.4': 'fixed-ranging',
        '<2.16.0,>=2.6': 'fixed-ranging',
        '<=2.18.2': 'at-most',
        '==2.10.*': 'floating-patch',
        '==1.1.post2': 'pinning',
        '>= 5.0.0 < 9.0.0': 'fixed-ranging',
        '13.0.x || > 13.1.0 < 14.0.0': 'or-expression',
        '=0.8.x': 'floating-patch',
        '>= 6.x.x': 'floating-major',
        '0.18 - 0.26 || ^0.26.0': 'or-expression',
        '7.*': 'floating-minor',
        '7.x': 'floating-minor',
        '>=10 <= 11': 'fixed-ranging',
        'v3.6.0-upgrade-to-lit.1': 'pinning',
        '11 || 12 || 13': 'or-expression',
        '>= 1.2.3 < 2.0.0': 'fixed-ranging',
        '>=3 || >=3.0.0-beta': 'or-expression',
        'v1.0.0': 'pinning',
        '>1.1.2-dev <1.1.2-ropsten': 'fixed-ranging',
        '0.6.X': 'floating-patch',
        '>=1.2.0,~=1.3': 'complex-expression',
        '~=1.3.0,<1.4': 'complex-expression',
        '~=1.3': 'floating-patch',
        '12.0.0-next-7.16': 'pinning',
        '2.0.80-am-fix-defaultprops-warnings3337': 'pinning',
        '4.*.*': 'floating-minor',
        '==23.4': 'pinning',
        '==938478': 'pinning',
        '==0.13.0.dev20210818061230': 'pinning',   
        '==0.13.0.dev20210818061230+g1a2b3c4': 'pinning',
        '=1': 'pinning',
        '=1.1': 'pinning',
        '=1.1.1': 'pinning',
        '=1.1.1.1': 'pinning',
        '<3.0dev,>=1.25.0': 'fixed-ranging',
        '<3.5.1,>=3.0.0b19': 'fixed-ranging',
        '==3.*': 'floating-minor',
        '<2.0.0dev,>=1.0.0': 'fixed-ranging',
        '~= 4.2': 'floating-patch',
        '>=4.12.5.0,<5.0.0.0': 'fixed-ranging',
        '<1.26.0.dev0': 'at-most',
        '19.1.4 - 21': 'fixed-ranging',
        '5.1.2 - 6.7.0': 'fixed-ranging',
        '2 - 4': 'fixed-ranging',
    }

    failed_tests = []
    for input_str, expected in test_cases.items():
        result = classify_version_requirement(input_str)
        if result != expected:
            failed_tests.append((input_str, expected, result))
        print(f"Test for '{input_str}': got '{result}' (expected '{expected}')")
    
    if failed_tests:
        print("\nTest Failures:")
        for input_str, expected, result in failed_tests:
            print(f"Failed for '{input_str}': Expected '{expected}' but got '{result}'")

if __name__ == "__main__":
    run_spec_type_tests()
    run_on_file()
