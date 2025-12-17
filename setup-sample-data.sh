#!/bin/bash
set -e

# Setup Sample Data Script
echo "=========================================="
echo "EDI Monitor - Sample Data Setup"
echo "=========================================="

S3_BUCKET="${S3_BUCKET:-edi-monitor}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "S3 Bucket: $S3_BUCKET"
echo "AWS Region: $AWS_REGION"
echo ""

# Check if sample data directory exists
if [ ! -d "sample-data" ]; then
    echo "Creating sample-data directory..."
    mkdir -p sample-data/master-data
    mkdir -p sample-data/edi-mockdata
fi

# Create sample master data files
echo "Creating sample master data files..."

# KNA1 - Store master data
cat > sample-data/master-data/KNA1.csv << 'EOF'
GP,Name,City,Region
1001,Store Tel Aviv Central,Tel Aviv,Central
1002,Store Jerusalem West,Jerusalem,Jerusalem
1003,Store Haifa North,Haifa,North
1004,Store Beer Sheva South,Beer Sheva,South
1005,Store Netanya Coast,Netanya,Central
EOF

# LFA1 - Vendor master data
cat > sample-data/master-data/LFA1.csv << 'EOF'
EN,Name,City,Type
V001,Supplier Alpha Ltd,Tel Aviv,Food
V002,Supplier Beta Industries,Haifa,Electronics
V003,Supplier Gamma Corp,Jerusalem,Textiles
V004,Supplier Delta Trading,Ashdod,General
V005,Supplier Epsilon Dist,Rishon,Food
EOF

# MAKT - Material descriptions
cat > sample-data/master-data/MAKT.csv << 'EOF'
Material,Description
7290000001234,חלב 3% 1 ליטר
7290000001241,לחם פרוס שחור
7290000001258,גבינה צהובה פרוסה
7290000001265,יוגורט תותים 150 גרם
7290000001272,ביצים גודל L 12 יחידות
7290000001289,עגבניות שרי 250 גרם
7290000001296,מלפפון חמוץ צנצנת
7290000001302,שמן זית 500 מ"ל
7290000001319,סוכר לבן 1 ק"ג
7290000001326,קמח לבן 1 ק"ג
EOF

# YLO_SNXT_EDI_H - Header EDI data
cat > sample-data/edi-mockdata/YLO_SNXT_EDI_H.csv << 'EOF'
A,B,C,D,E,F,G,H,Timestamp
DOC001,V001,2024-01-15,1001,INV,123,1500.00,104,2024-01-15T08:30:00
DOC002,V002,2024-01-15,1002,INV,124,2300.50,,2024-01-15T09:15:00
DOC003,V003,2024-01-15,1003,INV,125,1800.00,114,2024-01-15T10:00:00
DOC004,V004,2024-01-15,1004,INV,126,3200.00,,2024-01-15T10:45:00
DOC005,V005,2024-01-15,1005,INV,127,2100.00,104,2024-01-15T11:30:00
DOC006,V001,2024-01-15,1001,INV,128,1750.00,114,2024-01-15T12:15:00
DOC007,V002,2024-01-15,1002,INV,129,2900.00,,2024-01-15T13:00:00
DOC008,V003,2024-01-15,1003,INV,130,1950.00,104,2024-01-15T13:45:00
DOC009,V004,2024-01-15,1004,INV,131,2650.00,,2024-01-15T14:30:00
DOC010,V005,2024-01-15,1005,INV,132,3100.00,114,2024-01-15T15:15:00
EOF

# YLO_SNXT_EDI_I - Item EDI data
cat > sample-data/edi-mockdata/YLO_SNXT_EDI_I.csv << 'EOF'
A,B,C,D,E,F,G,H
DOC001,7290000001234,50,125.00,EA,1,,104
DOC001,7290000001241,30,90.00,EA,2,,
DOC001,7290000001258,25,150.00,EA,3,,
DOC002,7290000001265,100,200.00,EA,1,,
DOC002,7290000001272,40,180.00,EA,2,,
DOC003,7290000001289,60,120.00,EA,1,,114
DOC003,7290000001296,35,140.00,EA,2,,
DOC004,7290000001302,45,225.00,EA,1,,
DOC004,7290000001319,80,160.00,EA,2,,
DOC005,7290000001326,55,220.00,EA,1,,104
DOC005,7290000001234,40,100.00,EA,2,,104
DOC006,7290000001241,70,210.00,EA,1,,114
DOC006,7290000001258,30,180.00,EA,2,,
DOC007,7290000001265,90,270.00,EA,1,,
DOC007,7290000001272,50,225.00,EA,2,,
DOC008,7290000001289,65,195.00,EA,1,,104
DOC008,7290000001296,45,180.00,EA,2,,
DOC009,7290000001302,75,300.00,EA,1,,
DOC009,7290000001319,100,200.00,EA,2,,
DOC010,7290000001326,85,340.00,EA,1,,114
DOC010,7290000001234,60,150.00,EA,2,,
EOF

echo "✓ Sample data files created"
echo ""

# Upload to S3
echo "Uploading sample data to S3..."

# Upload master data
aws s3 cp sample-data/master-data/ "s3://${S3_BUCKET}/master-data/" \
    --recursive \
    --region "${AWS_REGION}"

# Upload EDI mock data
aws s3 cp sample-data/edi-mockdata/ "s3://${S3_BUCKET}/edi-mockdata/" \
    --recursive \
    --region "${AWS_REGION}"

echo "✓ Sample data uploaded to S3"
echo ""

echo "=========================================="
echo "Sample Data Setup Complete!"
echo "=========================================="
echo ""
echo "Data uploaded to:"
echo "  - s3://${S3_BUCKET}/master-data/"
echo "  - s3://${S3_BUCKET}/edi-mockdata/"
echo ""
