#!/usr/bin/env python
#------------------------------------------------------------------------------
#
#   Add quality metadata to EOP metadata.
#
# Project: XML Metadata Handling
# Authors: Martin Paces <martin.paces@eox.at>
#
#-------------------------------------------------------------------------------
# Copyright (C) 2013 EOX IT Services GmbH
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies of this Software or works derived from this Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#-------------------------------------------------------------------------------

import re
import sys
import os.path
from copy import deepcopy
from lxml import etree as et

RE_QNAME = re.compile(r"(?:{(.*)})?(.*)")
OM_RESULT_QUALITY = "{http://www.opengis.net/om/2.0}resultQuality"
OM_RESULT = "{http://www.opengis.net/om/2.0}result"

def split_name(qname):
    match = RE_QNAME.match(qname)
    if match:
        return match.groups()
    else:
        return (None, None)

def insert_before(elm_parent, tag_ref_list, elm_new):
    for idx, elm in enumerate(elm_parent):
        if elm.tag in tag_ref_list:
            elm_parent.insert(idx, elm_new)
            break;
    else:
        elm_parent.append(elm_new)

def insert_dq_in_eop(xml_eop, xml_dqm, replace=False):
    xml_eop_root = xml_eop.getroot()
    xml_dqm_root = xml_dqm.getroot()

    # remove all previus DQ element if REPLACE requested
    if replace:
        for elm in xml_eop_root:
            if elm.tag == OM_RESULT_QUALITY:
                xml_eop_root.remove(elm)

    # insert each DQ_Element
    for dq_elm in xml_dqm_root:
        elm = et.Element(OM_RESULT_QUALITY)
        elm.append(deepcopy(dq_elm))
        insert_before(xml_eop_root, (OM_RESULT,), elm)

    return xml_eop

if __name__ == "__main__":

    # TODO: to improve CLI
    EXENAME = os.path.basename(sys.argv[0])
    DEBUG = False
    REPLACE = False
    PRETTY = False

    try:
        XML_EOP = sys.argv[1]
        XML_DQM = sys.argv[2]
        for arg in sys.argv[3:]:
            if arg == "DEBUG":
                DEBUG = True # dump debuging output
            elif arg == "REPLACE":
                REPLACE = True # dump debuging output
            elif arg == "PRETTY":
                PRETTY = True # dump debuging output

    except IndexError:
        sys.stderr.write("ERROR: %s: Not enough input arguments!\n"%EXENAME)
        sys.stderr.write("\nAdd (or replace) data quality metadata\n")
        sys.stderr.write("to the EOP metadata.\n")
        sys.stderr.write("USAGE: %s <eop-xml> <dq-iso-xml> [DEBUG][REPLACE]\n"%EXENAME)
        sys.exit(1)

    if DEBUG:
        print >>sys.stderr, "eop-xml:  ", XML_EOP
        print >>sys.stderr, "dq-xml:   ", XML_DQM
        print >>sys.stderr, "REPLACE:  ", REPLACE
        print >>sys.stderr, "PRETTY:   ", PRETTY

#------------------------------------------------------------------------------

    try:
        xml_eop = et.parse(XML_EOP, et.XMLParser(remove_blank_text=True))
        xml_dqm = et.parse(XML_DQM, et.XMLParser(remove_blank_text=True))

        xml_eop_name = split_name(xml_eop.getroot().tag)
        if xml_eop_name[1] != "EarthObservation" and \
            not (xml_eop_name[0] or "").startswith("http://www.opengis.net/"):
            raise ValueError("Not EOP metadata! %s"% xml_eop.getroot().tag)

        if xml_dqm.getroot().tag != "{http://www.isotc211.org/2005/gmd}DQ_DataQuality":
            raise ValueError("Not DQ metadata! %s"% xml_dqm.getroot().tag)

        xml_out = insert_dq_in_eop(xml_eop, xml_dqm, REPLACE)

        print et.tostring(xml_out, pretty_print=PRETTY, xml_declaration=True, encoding="utf-8"),

    except Exception as exc:
        print >>sys.stderr, "ERROR: %s: %s "%(EXENAME, exc)
        sys.exit(1)
