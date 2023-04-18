reportextension 50005 Ext_StandardSalesQuote extends "Standard Sales - Quote"
{
    //RDLCLayout = 'Layout/StandardSalesQuote.rdl';
    RDLCLayout = 'Layout/ExtSalesQuote.rdlc';
    dataset
    {
        // Add changes to dataitems and columns here
        add(Header)
        {
            column(Tooling_Lead_Time; "Tooling Lead Time")
            {
            }
            column(Sample_Lead_Time; "Sample Lead Time")
            {
            }
            column(Production_Lead_Time; "Production Lead Time")
            {
            }
            column(Transit_Lead_Time; "Transit Lead Time")
            {
            }
            column(Quoted_Currency; "Quoted Currency")
            {
            }
            column(Tooling_Payment_Terms; "Tooling Payment Terms")
            {
            }
            column(Production_Terms; "Production Terms")
            {
            }
            column(PPAP_Requirement; "PPAP Requirement")
            {
            }
            column(Technical_Review; "Technical Review")
            {
            }
            column(UserName; UserName)
            {
            }
            column(UserEmail; UserEmail)
            {
            }
            column(UserPhone; UserPhone)
            {
            }
            column(Your_Reference; "Your Reference")
            {
            }
            column(IncoTerms; IncoTerms)
            {
            }
            column(ValidTo; "Document Date" + 30)
            {
            }
        }
        add(Line)
        {
            column(Cstm_Description; Cstm_Description)
            {
            }
            column(RevisionMaterialsFinish; RevisionMaterialsFinish)
            {
            }
        }
    }
}
