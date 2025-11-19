# MAD4HATTER

## MAD4HATTER Overview
Add mad4hatter/scientific overview here 

## Setting up your Terra workspace Metadata Tables
1. To run the main [Mad4Hatter](https://dockstore.org/workflows/github.com/broadinstitute/mad4hatter_wdls/Mad4Hatter:main?tab=info) workflow, you'll need to set up your Terra 
   workspace with the appropriate metadata tables. Since the workflow is designed to run once per dataset (not once 
   per sample), there will be two tables required in your Terra workspace. For this example, we'll call the first 
   table `sample` and the second tale `sample_set`. However, these can be customized if you'd prefer different names.
2. For the `sample` table, while you can always add additional columns, the minimum that will be required are the 
   following columns:
- `sample_id` - The sample ID 
- `forward` - The path to the forward FASTQ file
- `reverse` The path to the reverse FASTQ file
3. The easiest way to add this to Terra is to create a tsv (for example, called `sample.tsv`). Ensure the primary 
   key header is labeled using the name of the file, followed with `_id` (for example, `sample_id` in this case). The 
   remaining columns can have any headers that make sense for the metadata if `read1` and `read2` are not desired. 
   Any additional columns can be added to the tsv as well, if desired. 
4. Once you have created the tsv, navigate to the "Data" tab in your Terra workspace, and click on the 
   "Import Data" button. Select the tsv file you created, and Terra will create a new table in your workspace 
   with the contents of the tsv. This table will be called `sample` (or whatever you named the tsv file).
5. Next, you'll need to create a `sample_set` table which is how Terra will know which samples to process as part of 
   one dataset. If you're following the naming convention in this example, you'll need the following headers exactly: 
- `sample_set_id` - This will be the dataset name - use the same name for all rows (for example `MyDataset1`)
- `sample` - This will be all samples to be included in the dataset - each sample should be listed in its own row
6. As with the `sample` table, create a tsv (for example, called `sample_set.tsv`) with the appropriate headers 
   and contents. Then, navigate to the "Data" tab in your Terra workspace, and click on the "Import Data" button. 
   Select the tsv file you created, and Terra will create a new table in your workspace with the contents of the tsv. 
   This table will be called `sample_set` (or whatever you named the tsv file).
7. Once both tables are created, you can navigate to the "Data" tab in your Terra workspace to view and verify 
   that the tables have been created correctly with the appropriate contents.
8. Next, import your workflows (see directions below). 

## Importing Workflows to Terra Workspace  
There are three workflows available in this repository ([Mad4Hatter](https://dockstore.org/workflows/github.com/broadinstitute/mad4hatter_wdls/Mad4Hatter:main?tab=info), [Mad4HatterPostProcessing](https://dockstore.org/workflows/github.com/broadinstitute/mad4hatter_wdls/Mad4HatterPostProcessing:main?tab=info), and 
[Mad4HatterQcOnly](https://dockstore.org/workflows/github.com/broadinstitute/mad4hatter_wdls/Mad4HatterQcOnly:main?tab=info)), which can be 
run via Terra. To import your desired workflow into your Terra workspace, please follow the instructions below:
1. Create a new Terra workspace, use an existing one, or clone an existing one. Note that if you're cloning an 
   existing workspace that already has your desired workflow(s), you can skip the rest of these steps.
2. Navigate to the "Workflows" tab in your Terra workspace.
3. Click on "Find a Workflow" and select the "Dockstore.org" option. This will bring you to the Dockstore website.
4. In Dockstore, search for "MAD4HatTeR" and select the appropriate workflow from the search results.
5. In the new page that opens, under "Launch with", select Terra.
6. Enter your destination workspace name in the new page that opens and select "Import". 
7. You will be redirected back to your Terra workspace, where you can configure and run the workflow (see directions 
   below). 

## Running the main Mad4Hatter Workflow
1. Prerequisites include setting up [your metadata](#setting-up-your-terra-workspace-metadata-tables) and [importing the workflow](#importing-workflows-to-terra-workspace) into your Terra workspace.
2. Once those steps are complete, navigate to the "Workflows" tab in your Terra workspace.
3. If running [Mad4Hatter](https://dockstore.org/workflows/github.com/broadinstitute/mad4hatter_wdls/Mad4Hatter:main?tab=info) workflow, select the workflow under the "Workflows" tab. This will bring up the configuration page. 
   First, select the "Run workflow(s) with inputs defined by data table" option. Under "Step 1: Select data table", 
   choose the `sample_set` table (or whatever you named this table in the earlier steps). Under "Step 2: Select 
   Data", toggle the "Chose specific sample_sets to process" option in the popup, and then select your desired 
   dataset. Click "Ok". 
4. Next, you'll have to configure your inputs. The two inputs to pay attention to specifically are `forward_fastqs` and 
   `reverse_fastqs`. The "Input value" for `forward_fastqs` should be `this.samples.read1` (`read1` is the column 
   header, so if you named it something different, use that instead). The input for `reverse_fastqs` should be `this.samples.read2` (or whatever you named that column if not `read2`).
5. The rest of the inputs can be configured as desired. If you uploaded additional columns to your `sample_set` table, you can use those as inputs as well here by using `this.samples.{column_name}`. If you uploaded additional columns to your `sample` table, you can use those as input as 
   well here by using `this.{column_name}`. Otherwise, you can put in literal hard-coded strings and file paths as 
   needed. 
6. Once all inputs are configured, you can click "Save" and then "Launch" to start the workflow. If everything was 
   configured correctly, you'll see "You are launching 1 workflow run in this submission." in the popup. If you see 
   that more than one workflow is being launched, go back through the configuration steps and ensure that a "set" of 
   samples has been selected, as this workflow is designed to run once per dataset.
7. After launching, you can monitor the progress of the workflow in the "Submission History" tab. By default, Terra 
   only displays workflows that have been launched in the past 30 days. If you want to see submission history from 
   all time, make sure you select "All submissions" from the Date range drop down at the top of the page. 
