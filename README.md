# MAD4HATTER

## Creating and Setting Up Your Terra Workspace for Mad4Hatter

### Creating a Workspace
To use Mad4Hatter in Terra, you'll first need to create a Terra workspace.

#### Cloning a Workspace 
The first option is to clone this template workspace. This is the easiest option, and the recommended way to get started quickly.
See directions [here](https://support.terra.bio/hc/en-us/articles/360026130851-How-to-clone-your-own-workspace) on cloning a Terra workspace.
This workspace already has the Mad4Hatter workflow imported, so you can skip the "Importing Workflows to Terra 
Workspace" section below if you choose this option. It also contains some 
example metadata loaded into the metadata tables as an example of how to structure your own metadata. 

#### Creating a New Workspace 
The second option is to create a new Terra workspace from scratch. To do this, click on "Workspaces" from the 
dropdown menu in the top left corner of the Terra homepage. Then, click on the `+` button at the top left of the 
page to create a new workspace. You'll be prompted to enter information about your new workspace. 


### Importing Data and Setting up Terra Metadata Tables
See the directions below for two options - one for both importing new data into your Terra workspace's GCP bucket 
and setting up metadata, and another for only setting up metadata tables if your data has already been imported. 

#### Importing New Data and Setting up Metadata
If you have _not_ yet imported your data into your workspace's GCP bucket, you can follow directions here for both 
importing your data and creating metadata tables. Note that your data files must be on your local machine for these 
directions to work for you. 
1. First, follow [these directions](https://support.terra.bio/hc/en-us/articles/4419428208411-Upload-data-and-populate-the-table-with-linked-file-paths) **until Step 3. 
   Upload Files**. The linked directions will guide you through creating a collection and uploading your data files. 
2. Once you have uploaded your data files, click "Next" which will prompt you to make a choice to either use the 
   autogenerate feature or upload your own metadata files. Here, you can select "AUTOGENERATE TABLE FOR SINGLE OR 
   PAIRED END SEQUENCING". This will automatically create a new table for you (it will give you a preview of what 
   the table will look like). If everything looks good, select "Create Table". The new table that gets created will 
   have the same name as the collection you created in the first step. Your data files will be located within the 
   GCP bucket of the workspace.  


#### Setting up Metadata with Already Imported Data
If you have _already_ imported your data into your workspace's GCP bucket, you can follow directions here for simply 
creating metadata tables:

1. To run the main [Mad4Hatter](https://dockstore.org/workflows/github.com/broadinstitute/mad4hatter_wdls/Mad4Hatter:main?tab=info) workflow, you'll need to set up your Terra 
   workspace with the appropriate metadata tables. For this example, we'll call our example  
   table `sample`. However, this can be customized if you'd prefer a different name.
2. For the `sample` table, while you can always add additional columns, the minimum that will be required are the 
   following columns:
      - `sample_id` - The sample ID 
      - `forward` - The GCP path to the forward FASTQ file
      - `reverse` The GCP path to the reverse FASTQ file
3. You'll need to create a tsv (for example, called `sample.tsv`). Ensure the primary 
   key header is labeled using the name of the file, followed with `_id` (for example, `sample_id` in this case). The 
   remaining columns can have any headers that make sense for the metadata if `forward` and `reverse` are not desired. 
   Any additional columns can be added to the tsv as well, if desired. 
4. Once you have created the tsv, navigate to the "Data" tab in your Terra workspace, and click on the 
   "Import Data" button. Select the tsv file you created, and Terra will create a new table in your workspace 
   with the contents of the tsv. This table will be called `sample` (or whatever you named the tsv file).
5. Next, import your workflows (see directions below). 

## Importing Workflows to Terra Workspace
There are three workflows available to run - ([Mad4Hatter](https://dockstore.org/workflows/github.com/broadinstitute/mad4hatter_wdls/Mad4Hatter:main?tab=info), [Mad4HatterPostProcessing](https://dockstore.org/workflows/github.com/broadinstitute/mad4hatter_wdls/Mad4HatterPostProcessing:main?tab=info), and 
[Mad4HatterQcOnly](https://dockstore.org/workflows/github.com/broadinstitute/mad4hatter_wdls/Mad4HatterQcOnly:main?tab=info)). To import your desired workflow into your Terra workspace, please follow the instructions below:
1. Create a new Terra workspace, use an existing one, or clone an existing one. See the directions above if you have not 
   yet completed this step. Note that if you're cloning an existing workspace that already has your desired workflow(s) (for example, this template workspace), you can skip the rest of these steps.
2. Navigate to the "Workflows" tab in your Terra workspace.
3. Click on "Find a Workflow" and select the "Dockstore.org" option. This will bring you to the Dockstore website.
4. In Dockstore, search for "MAD4HatTeR" and select the appropriate workflow from the search results.
5. In the new page that opens, under "Launch with", select Terra.
6. Enter your destination workspace name in the new page that opens and select "Import". 
7. You will be redirected back to your Terra workspace, where you can configure and run the workflow (see directions 
   below). 

## Running the main Mad4Hatter Workflow
1. Navigate to the "Workflows" tab in your Terra workspace. 
2. If running [Mad4Hatter](https://dockstore.org/workflows/github.com/broadinstitute/mad4hatter_wdls/Mad4Hatter:main?tab=info) workflow, select the workflow under the "Workflows" tab. This will bring up the configuration page. 
   First, select the "Run workflow(s) with inputs defined by data table" option. Under "Step 1: Select data table", 
   you'll see an option that is named like `YOUR_TABLE_set`. This should be your table that contains the forward and 
   reverse reads with the _suffix `_set` appended to it. Select that table. For example, if your table is named 
   `sample`, select `sample_set`.
3. Next, click on "Select Data", and select all the samples that should be processed together as part of a dataset. 
   Optionally, you can rename the new set that gets generated if you'd like. Otherwise, it will have an 
   auto-generated name with the timestamp appended. Click "OK". 
3. Next, you'll have to configure your inputs. The two inputs to pay attention to specifically are `forward_fastqs` and 
   `reverse_fastqs`. The "Input value" for `forward_fastqs` should be `this.{your_table_name}s.read1` (`read1` is the 
   column header, so if you named it something different, use that instead). The input for `reverse_fastqs` should 
   be `this.{your_table_name}s.read2` (or whatever you named that column if not `read2`). So for example, if your 
   table containing your forward and reverse reads is named `sample`, the inputs would be `this.samples.read1` and 
   `this.samples.read2` respectively. Be sure to make the table name plural by adding an `s` after it (`sample` vs. 
   `samples`). 
4. The rest of the inputs can be configured as desired.
5. Once all inputs are configured, you can click "Save" and then "Launch" to start the workflow. If everything was 
   configured correctly, you'll see "You are launching 1 workflow run in this submission." in the popup. If you see 
   that more than one workflow is being launched, go back through the configuration steps and ensure that a "set" of 
   samples has been selected, as this workflow is designed to run once per dataset. 
6. After launching, you can monitor the progress of the workflow in the "Submission History" tab. By default, Terra 
   only displays workflows that have been launched in the past 30 days. If you want to see submission history from 
   all time, make sure you select "All submissions" from the Date range drop down at the top of the page. 
