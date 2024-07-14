#!/usr/bin/env python3

import os
import sys


raw_specs = [
    'MulticastSocket_TTL',
    'RuntimePermission_NullAction',
    'TreeSet_Comparable',
    'Long_BadDecodeArg',
    'Arrays_MutuallyComparable',
    'Runnable_OverrideRun',
    'Byte_BadDecodeArg',
    'Socket_TrafficClass',
    'Short_BadDecodeArg',
    'CharSequence_UndefinedHashCode',
    'InetSocketAddress_Port',
    'IDN_ToAscii',
    'SocketPermission_Actions',
    'Integer_BadDecodeArg',
    'Dictionary_NullKeyOrValue',
    'ServerSocket_Timeout',
    'Authenticator_OverrideGetPasswordAuthentication',
    'Long_BadParsingArgs',
    'EnumSet_NonNull',
    'NetPermission_Name',
    'SortedSet_Comparable',
    'CharSequence_NotInSet',
    'InputStream_MarkReset',
    'Random_OverrideNext',
    'Collections_UnnecessaryNewSetFromMap',
    'HttpCookie_Name',
    'Object_NoClone',
    'Short_BadParsingArgs',
    'Socket_Timeout',
    'ContentHandler_GetContent',
    'Comparable_CompareToNull',
    'Arrays_Comparable',
    'HttpCookie_Domain',
    'Comparable_CompareToNullException',
    'ServerSocket_Backlog',
    'RuntimePermission_PermName',
    'URLEncoder_EncodeUTF8',
    'Collections_Comparable',
    'DatagramSocket_SoTimeout',
    'NetPermission_Actions',
    'Serializable_NoArgConstructor',
    'ArrayDeque_NonNull',
    'EnumMap_NonNull',
    'Enum_NoExtraWhiteSpace',
    'DatagramSocket_Port',
    'String_UseStringBuilder',
    'Collections_CopySize',
    'URLDecoder_DecodeUTF8',
    'DatagramPacket_Length',
    'Closeable_MeaninglessClose',
    'Character_ValidateChar',
    'URLConnection_OverrideGetPermission',
    'Arrays_DeepHashCode',
    'TreeMap_Comparable',
    'Set_ItselfAsElement',
    'CharSequence_NotInMap',
    'DatagramPacket_SetLength',
    'Object_MonitorOwner',
    'DatagramSocket_TrafficClass',
    'System_NullArrayCopy',
    'InvalidPropertiesFormatException_NonSerializable',
    'Map_ItselfAsValue',
    'ClassLoader_UnsafeClassDefinition',
    'PriorityQueue_NonNull',
    'Map_ItselfAsKey',
    'Collections_ImplementComparable',
    'Collection_HashCode',
    'InetAddress_IsReachable',
    'PriorityQueue_NonComparable',
    'Vector_InsertIndex',
    'Byte_BadParsingArgs',
    'Reader_MarkReset',
    'ServerSocket_Port',
    'File_LengthOnDirectory'
]

raw_specs_set = set()
for spec in raw_specs:
    raw_specs_set.add(spec + "Monitor")


def generate(traces_dir):
    id_to_trace = {}
    output = ['=== UNIQUE TRACES ===\n']
    
    with open(os.path.join(traces_dir, 'traces-id.txt')) as f:
        header = False
        for line in f.readlines():
            line = line.strip()
            if not header or not line:
                header = True
                continue
            id, _, trace = line.partition(' ')
            id_to_trace[id] = trace
    
    with open(os.path.join(traces_dir, 'specs-frequency.csv')) as f:
        for line in f.readlines():
            line = line.strip()
            if not line or line == 'OK':
                continue
        
            id, _, spec_to_freq = line.partition(' ')
            if len(spec_to_freq) <= 2:
                print('Error processing spec ID: {}'.format(id))
                continue
        
            total_freq = 0
            spec_to_freq = spec_to_freq[1:-1]
            for spec_str in spec_to_freq.split(', '):
                spec, freq = spec_str.split('=')
                if spec not in raw_specs_set:
                    total_freq += int(freq)

            if total_freq > 0:
                output.append('{} {}\n'.format(total_freq, id_to_trace[id]))
    
    with open(os.path.join(traces_dir, 'unique-traces-noraw.txt'), 'w') as f:
        f.writelines(output)


def main(argv=None):
    argv = argv or sys.argv
    
    if len(argv) < 2:
        print('Usage: python3 count-traces-frequency-without-raw.py <traces-dir>')
        exit(1)
    traces_dir = argv[1]
    
    if not os.path.exists(os.path.join(traces_dir, 'specs-frequency.csv')):
        print('Cannot find specs-frequency.csv')
        exit(1)
    
    if not os.path.exists(os.path.join(traces_dir, 'traces-id.txt')):
        print('Cannot find unique-traces.txt')
        exit(1)

    generate(traces_dir)
    
    
if __name__ == '__main__':
    main()
